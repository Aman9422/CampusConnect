/**
 * CampusConnect — AI Resume Review Cloud Function + helpers.
 *
 * Handles:
 *   - Resume review (ATS score, missing keywords, feedback)
 *   - PDF extraction from Firebase Storage
 *   - Crash-safe quota reservation (monthly limit + daily sweep)
 *   - Quota rollback on AI failure
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
// v8.5 (R2): server-side PDF → text extraction for the Resume Reviewer.
// Deep require avoids pdf-parse's main-entry test-data side effect; the
// extractor is pure-JS and runs on the Node 20 functions runtime.
const pdfParse = require("pdf-parse/lib/pdf-parse.js");
const {generateResumeReviewAI} = require("./aiProvider");
// v9.2.5: bucket-resilient resume-object reader (see the module docs for why
// the implicit `admin.storage().bucket()` name is not safe for this project).
const {downloadResumeBuffer} = require("./resumeStorage");
const {logAnalyticsEvent} = require("../helpers/shared");
// v9.0 (IMP-15): unified AI quota management — `resume_usage/{uid}` is now a
// legacy mirror; the authoritative store is `user_ai_quotas/{uid}.resumeReview`.
const quota = require("./quota");

// ===============================================
// CONSTANTS
// ===============================================

const RESUME_MONTHLY_LIMIT = 5; // Free reviews per month
const RESUME_MAX_LENGTH = 5000; // Maximum resume characters
const RESUME_MIN_LENGTH = 100; // Minimum resume characters

// ===============================================
// EXPORTS
// ===============================================

/**
 * AI Resume Review Cloud Function (Version 6.7)
 *
 * Analyzes resumes for ATS compatibility and provides actionable feedback.
 *
 * Features:
 * - ATS score calculation
 * - Missing keywords detection
 * - Bullet point improvements
 * - Section-by-section advice
 * - Monthly usage limits (free tier)
 *
 * @param {object} request - Contains userId, resumeText, targetRole
 * @param {object} response - Returns review analysis and usage metadata
 */
// v8.4.2 (S6b/P3): CALLABLE (was HTTPS onRequest). The authenticated uid comes
// from `request.auth.uid` — a forged body/query `userId` can no longer spend
// the monthly quota or attach reviews to another account. The GET usage-check
// path is now the `{checkUsage: true}` callable flag.
exports.reviewResume = onCall(
    {maxInstances: 5, timeoutSeconds: 120, memory: "512MiB"},
    async (request) => {
      // v8.4.2 (S6b/P3): uid from Firebase Auth is the only identity source.
      const userId = request.auth?.uid;

      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to review your resume."
        );
      }

      // Usage check without submitting a review (replaces the old GET path).
      if (request.data?.checkUsage === true) {
        const usage = await getResumeUsage(userId);
        return {usage};
      }

      try {
        // Extract data from request
        const { resumeText, storagePath, targetRole, experienceLevel } =
            request.data || {};

        // v9.2.5: a stage breadcrumb on ENTRY. Every later failure logs its
        // own stage, so an "INTERNAL" in the client can always be tied to a
        // named step in the function log. Previously the first log line sat
        // AFTER the Storage read, so a failing read left no trace whatsoever.
        console.log(
            `reviewResume: received request (source: ` +
            `${storagePath ? "uploaded" : "pasted"})`
        );

        // v8.5 (R3): resolve the resume text either from the uploaded PDF
        // (`storagePath`) or the pasted manual text fallback.
        let trimmedResume;
        let reviewSource = "pasted";
        if (storagePath) {
          trimmedResume = await resumeTextFromStorage(userId, storagePath);
          reviewSource = "uploaded";
        } else {
          if (!resumeText) {
            console.error(
                "reviewResume: rejected — neither a storage path nor resume " +
                "text was supplied."
            );
            throw new admin.functions.https.HttpsError(
                "invalid-argument",
                "Resume text is required."
            );
          }
          trimmedResume = resumeText.trim();
        }

        // Validate resume length (PDF path already truncated to max).
        if (trimmedResume.length < RESUME_MIN_LENGTH) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              `Resume too short. Minimum ${RESUME_MIN_LENGTH} characters required.`
          );
        }
        if (trimmedResume.length > RESUME_MAX_LENGTH) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              `Resume too long. Maximum ${RESUME_MAX_LENGTH} characters allowed.`
          );
        }

        console.log(`Resume review request from user: ${userId} (${reviewSource})`);
        console.log(`Resume length: ${trimmedResume.length} characters`);
        console.log(`Target role: ${targetRole || "General"}`);

        // v8.6 (MED 8): quota check + increment are now ONE transaction
        // (`consumeResumeQuota`) so two concurrent calls cannot both pass
        // the limit and exceed 5 monthly reviews. `getResumeUsage` is kept
        // for the read-only `checkUsage` path only.
        // v8.8.2 (A, HIGH): crash-safe reservation. `consumeResumeQuota`
        // stamps a per-request `pendingRequestId` / `pendingSince` on the
        // usage doc, so a 500/function-crash AFTER quota consumption but
        // BEFORE the AI-failure rollback no longer permanently burns a
        // credit — the daily `compensateStaleAIQuotas` sweep refunds any
        // reservation left stale for >24h. The reservation is cleared on
        // success (credit kept, review delivered) and on AI-failure rollback
        // (credit returned).
        let usageData;
        const requestId = crypto.randomUUID();
        try {
          usageData = await consumeResumeQuota(userId, requestId);
        } catch (quotaError) {
          if (quotaError instanceof admin.functions.https.HttpsError) {
            throw quotaError;
          }
          console.error("quota error in reviewResume:", quotaError);
          throw new admin.functions.https.HttpsError(
              "internal",
              "Could not verify your review quota. Please try again."
          );
        }

        // Generate AI review (Real AI via Groq/HuggingFace).
        let reviewResult;
        try {
          const aiResult = await generateResumeReviewAI(
              trimmedResume,
              targetRole || "General / Entry Level",
              experienceLevel || "Student / Fresher"
          );
          reviewResult = aiResult.review;
          console.log(`Resume review from provider: ${aiResult.providerUsed}`);
          // v8.8.2 (A): the review completed — keep the credit, clear the
          // reservation so the compensation sweep never refunds it.
          await clearResumeReservation(userId, requestId);
        } catch (aiError) {
          // v8.6 (HIGH 3): the AI provider failed — the user gets NO review
          // but already paid a credit. Roll it back so the quota is only
          // consumed for completed reviews.
          console.error("AI provider error in reviewResume:", aiError);
          try {
            await rollbackResumeUsage(userId, requestId);
            console.log("reviewResume: rolled back quota after AI failure");
          } catch (rollbackError) {
            console.error(
                "reviewResume: rollback of consumed quota failed:",
                rollbackError
            );
          }
          throw new admin.functions.https.HttpsError(
              "internal",
              "AI analysis failed. Please try again later."
          );
        }

        // v9.2 audit (§4.1, "resumeReviews is fully owner-writable"):
        // persist the review SERVER-side. The client no longer has create or
        // update access to `users/{uid}/resumeReviews` (firestore.rules), so
        // this Admin SDK write is the only way a review enters the collection
        // — a student can no longer hand-write an `atsScore` / `aiAnalysis`
        // document into the teacher analytics roll-ups. Best-effort: the AI
        // call already succeeded and the monthly credit is already spent, so
        // a persistence failure must not fail the request (the caller still
        // receives the review, it just will not appear in history).
        let reviewId = null;
        try {
          reviewId = await persistResumeReview(userId, reviewResult, targetRole);
        } catch (persistError) {
          console.error("reviewResume: failed to persist review:", persistError);
        }

        // Log analytics event
        await logAnalyticsEvent({
          eventType: "resume_review_completed",
          userId: userId,
          metadata: {
            resumeLength: trimmedResume.length,
            source: reviewSource,
            storagePath: storagePath || null,
            targetRole: targetRole || "General",
            atsScore: reviewResult.atsScore,
            monthlyUsage: usageData.monthlyCount,
          },
        });

        // Return successful response. `reviewId` is the persisted document id
        // (null when the best-effort persist failed).
        return {
          review: reviewResult,
          usage: usageData,
          reviewId: reviewId,
        };

      } catch (error) {
        // Re-throw validation/quota HttpsError as-is.
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        console.error("Error in reviewResume function:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Failed to analyze resume. Please try again later."
        );
      }
    }
);

// ===============================================
// PRIVATE HELPERS
// ===============================================

/**
 * v8.5 (R2/R3): Extract resume text from the authenticated user's uploaded
 * resume PDF in Firebase Storage.
 *
 * Security contract enforced here (never trust client-supplied identity):
 *   - [uid] is `request.auth.uid` from the callable context (authoritative).
 *   - [storagePath] is allowed ONLY when it exactly equals
 *     `resumes/{uid}/latest.pdf`. Any other path (other user, other file,
 *     different layout) is rejected with `invalid-argument`.
 *
 * @param {string} uid - Authenticated user id
 * @param {string} storagePath - Client-supplied storage path
 * @returns {Promise<string>} Extracted resume text (max RESUME_MAX_LENGTH)
 * @throws {HttpsError#invalid-argument|not-found}
 */
async function resumeTextFromStorage(uid, storagePath) {
  const expectedPath = `resumes/${uid}/latest.pdf`;
  if (typeof storagePath !== "string" || storagePath !== expectedPath) {
    console.error(
        `resumeTextFromStorage: rejected path ` +
        `${JSON.stringify(storagePath)}; only ` +
        `${expectedPath} is allowed for this account.`
    );
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "The supplied resume path is not a valid resume for this account."
    );
  }

  // v9.2.5: read the object through the bucket-resilient reader.
  //
  // The previous form — `admin.storage().bucket().file(storagePath)` — used
  // the bucket Firebase Admin resolves implicitly, which is
  // `app.options.storageBucket` and, when unset, the LEGACY
  // `<project>.appspot.com`. The Flutter client uploads through
  // `FirebaseStorage.instance`, which uses the bucket from `FirebaseOptions`
  // (`<project>.firebasestorage.app` for this project). When those two names
  // disagree, the PDF is present but the function reads the wrong bucket, and
  // the resulting 404 was then re-thrown as a TypeError by the
  // `instanceof admin.functions...` line below — reaching the client as a bare
  // `internal` / `INTERNAL`. The reader probes every plausible bucket name and
  // returns a TYPED outcome so "no file" and "wrong bucket" are
  // distinguishable (and logged with the bucket names tried).
  const download = await downloadResumeBuffer(storagePath);
  if (!download.ok) {
    if (download.reason === "not-found") {
      throw new admin.functions.https.HttpsError(
          "not-found",
          "Your uploaded resume could not be found in storage. Please upload " +
          "it again from your portfolio, then retry."
      );
    }
    if (download.reason === "too-large") {
      throw new admin.functions.https.HttpsError(
          "invalid-argument",
          "Resume exceeds the 5 MB limit. Please upload a smaller PDF."
      );
    }
    throw new admin.functions.https.HttpsError(
        "internal",
        "Could not read your resume. Please try again later."
    );
  }

  // An empty object cannot be a PDF; the reader already rejected that case
  // explicitly, so no separate empty-buffer branch is needed here.
  const data = download.buffer;

  let text;
  try {
    const parsed = await pdfParse(data);
    text = (parsed.text || "").replace(/\u0000/g, "").trim();
  } catch (parseError) {
    console.error(
        `resumeTextFromStorage: PDF parse failed for ${storagePath}:`,
        parseError.message || parseError
    );
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        "This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF."
    );
  }

  // v8.6 (LOW): a PDF with SOME text but under the minimum is a genuine short
  // resume, not an image — give it an accurate message instead of the
  // image-based mislabel. Only a completely empty extraction is treated as
  // scanned/image-only.
  if (text.length < RESUME_MIN_LENGTH) {
    // v9.2.5: this branch previously threw WITHOUT logging anything, so an
    // image-based or near-empty PDF produced a completely silent failure —
    // the "extracted N characters" log sits BELOW this check. The extracted
    // length is the one number that tells the two cases apart.
    console.error(
        `resumeTextFromStorage: extracted only ${text.length} characters ` +
        `from ${storagePath} (minimum ${RESUME_MIN_LENGTH}) — the PDF is ` +
        `${text.length > 0 ? "too short" : "image-based or unscannable"}.`
    );
    throw new admin.functions.https.HttpsError(
        "invalid-argument",
        text.length > 0
            ? `This resume is too short (${text.length} characters). Please upload a resume with at least ${RESUME_MIN_LENGTH} characters of text.`
            : "This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF."
    );
  }

  // Truncate to the same ceiling the manual path enforces.
  if (text.length > RESUME_MAX_LENGTH) {
    text = text.substring(0, RESUME_MAX_LENGTH);
  }

  console.log(
      `resumeTextFromStorage: extracted ${text.length} characters from ${storagePath}`
  );
  return text;
}

/**
 * Get resume usage without incrementing
 *
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Usage data
 */
async function getResumeUsage(userId) {
  try {
    return await quota.getFeatureUsage(userId, "resumeReview");
  } catch (error) {
    console.error("Error getting resume usage:", error);
    return {
      monthlyCount: 0,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
      lastResetMonth: null,
    };
  }
}

/**
 * v8.6 (MED 8): atomically check the monthly limit AND increment the quota.
 *
 * The old flow (`getResumeUsage` outside a transaction, then
 * `trackResumeUsage` inside one) was not atomic together: two concurrent
 * calls could both read `monthlyCount = 4`, both pass the check, and both
 * increment → 6+ reviews in a month. This helper performs check-then-increment
 * in a SINGLE transaction.
 *
 * v8.8.2 (A, HIGH): the consumed credit is now a per-request RESERVATION.
 * `pendingRequestId` / `pendingSince` are stamped on the usage doc at
 * consumption time so a crash/500 between consumption and the AI-failure
 * rollback can be detected and refunded by `compensateStaleAIQuotas`.
 * The reservation is cleared by [clearResumeReservation] on success and by
 * [rollbackResumeUsage] on AI failure.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - Unique id for this review request
 * @returns {Promise<object>} Usage data (post-increment)
 * @throws {HttpsError#resource-exhausted} when the monthly limit is reached
 */
async function consumeResumeQuota(userId, requestId) {
  return quota.consumeFeatureQuota(userId, "resumeReview", requestId);
}

/**
 * v8.8.2 (A, HIGH): clear the pending reservation on a usage doc.
 *
 * Called after a successful review (credit is kept — the reservation is just
 * un-stamped so the compensation sweep never refunds a delivered review).
 * Idempotent and best-effort: a stale reservation is harmless because
 * [compensateStaleAIQuotas] refunds it.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function clearResumeReservation(userId, requestId) {
  return quota.clearFeatureReservation(userId, "resumeReview", requestId);
}

/**
 * v8.6 (HIGH 3): compensate a consumed quota when the AI review call failed.
 *
 * `reviewResume` consumes the quota BEFORE the AI provider call so the limit
 * is enforced atomically. If the provider then fails, the user has paid a
 * credit without receiving a review — decrement it so credits are only spent
 * on completed reviews. Does not throw (best-effort rollback).
 *
 * v8.8.2 (A, HIGH): the rollback now also CLEARS this request's reservation
 * (`pendingRequestId` / `pendingSince`) in the SAME transaction, so the
 * compensation sweep never double-refunds (decrement + clear is atomic).
 * The requestId guard means only OUR failed request's reservation is
 * cleared — another in-flight request's reservation is never touched.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} requestId - The request id that owns the reservation
 * @returns {Promise<void>}
 */
async function rollbackResumeUsage(userId, requestId) {
  return quota.rollbackFeatureQuota(userId, "resumeReview", requestId);
}
/**
 * v9.2 audit (§4.1, "resumeReviews is fully owner-writable"): persist a
 * completed review to `users/{uid}/resumeReviews/{autoId}` with the Admin SDK.
 *
 * This is the ONLY writer of the collection (the owner create/update rules are
 * `false`), so a client can no longer forge an `atsScore` / `aiAnalysis`
 * document into the teacher analytics roll-ups.
 *
 * Field shape must stay in sync with `ResumeReviewHistory.fromFirestore`
 * (`lib/models/resume_review.dart`) and `ResumeHistoryService.saveReview`
 * (the deleted client writer).
 *
 * @param {string} userId - Authenticated user id (from request.auth.uid)
 * @param {object} reviewResult - AI review payload
 * @param {string|undefined} targetRole - Requested target role
 * @returns {Promise<string>} The persisted document id
 */
async function persistResumeReview(userId, reviewResult, targetRole) {
  const now = new Date();
  // UTC month key — the server is the single writer, so the streak/month
  // bucketing no longer has to agree with a client-local clock.
  const monthKey =
      `${now.getUTCFullYear()}-` +
      `${String(now.getUTCMonth() + 1).padStart(2, "0")}`;

  const ref = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("resumeReviews")
      .add({
        userId,
        atsScore: typeof reviewResult.atsScore === "number" ?
          reviewResult.atsScore : 0,
        strengths: reviewResult.strengths || [],
        missingKeywords: reviewResult.missingKeywords || [],
        formatIssues: reviewResult.formatIssues || [],
        bulletImprovements: reviewResult.bulletImprovements || [],
        sectionAdvice: reviewResult.sectionAdvice || {},
        overallAdvice: reviewResult.overallAdvice || "",
        hireabilityVerdict: reviewResult.hireabilityVerdict || "",
        targetRole: targetRole || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        monthKey,
        // Marks this as a server-authored review (informational; the rules no
        // longer gate on it because a field-referencing rule would break the
        // unbounded teacher collectionGroup query).
        source: "server",
      });

  console.log(`reviewResume: persisted review ${ref.id} for user ${userId}`);
  return ref.id;
}
