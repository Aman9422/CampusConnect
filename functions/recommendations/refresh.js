/**
 * CampusConnect — Recommendation Refresh (callable + engine orchestrator).
 *
 * v8.6 (MED 7): client entry point that rebuilds the user's recommendations
 * through the SERVER engine.
 *
 * Single-writer contract: `refreshRecommendationsForStudent` (also invoked by
 * the profile-update and resume-review triggers) is the ONLY component that
 * writes `users/{uid}/recommendations/*` and `recommendations_meta/summary`.
 *
 * v9.2.2 (§2 — refresh deduplication): the orchestrator now computes a
 * FINGERPRINT of everything the deterministic engine reads (user signals,
 * resume-review inputs, applied placements, the candidate sets) and stores it
 * on `recommendations_meta/summary`. When the same fingerprint is presented
 * again — the profile trigger (S1) firing right after the client bootstrap
 * callable (C1), or two concurrent callers — the work is SKIPPED instead of
 * regenerating the identical set (engine + AI enrichment + a full rewrite).
 *
 * Regeneration is still guaranteed whenever a real input changes:
 *   * any profile/portfolio/resume signal change alters the fingerprint;
 *   * adding/removing a candidate (placement/opportunity/alumni) alters it;
 *   * an EXPIRED active recommendation forces a regeneration;
 *   * `force: true` (explicit user refresh) always runs.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const crypto = require("crypto");
const admin = require("firebase-admin");
const {buildRecommendations, extractPortfolio} = require("./engine");
const {enrichRecommendationExplanations} = require("./ai_explanations");
const {maybeCreateNotification} = require("../helpers/shared");

// v9.0 (IMP-8): cursor-based pagination for the bulk candidate queries in
// `refreshRecommendationsForStudent`. Firestore caps a single query's result
// set, and a single `.limit(120)` would silently drop candidates once the user
// base grows past that. Paging with `startAfter` keeps each read small and
// avoids dropping matches. `RECOMMENDATION_CANDIDATE_MAX` bounds the engine
// workload; `RECOMMENDATION_CANDIDATE_PAGE_SIZE` keeps each round-trip small.
// Both are env-tunable (defaults are a modest increase from the prior 120 cap).
const RECOMMENDATION_CANDIDATE_PAGE_SIZE =
    parseInt(process.env.RECOMMENDATION_CANDIDATE_PAGE_SIZE || "100", 10);
const RECOMMENDATION_CANDIDATE_MAX =
    parseInt(process.env.RECOMMENDATION_CANDIDATE_MAX || "200", 10);

// v9.2.2 (§2): bump whenever the deterministic engine's OUTPUT shape/ranking
// changes so previously-materialized fingerprints are treated as stale (the
// engine must re-run once after a logic change). Keep in sync with
// `docs/v9_2_2_optimization_report.md`.
const RECOMMENDATION_ENGINE_VERSION = 2;

// ===============================================
// FINGERPRINT
// ===============================================

/**
 * Deterministic JSON with SORTED object keys, so two structurally equal inputs
 * always hash to the same string regardless of key insertion order.
 *
 * @param {*} value
 * @returns {string}
 */
function stableStringify(value) {
  if (value === null || value === undefined) return "null";
  if (typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  const keys = Object.keys(value).sort();
  return `{${keys
      .map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`)
      .join(",")}}`;
}

/**
 * The portfolio as it should participate in the fingerprint: identical to the
 * document value but WITHOUT its own `metadata` sub-map, mirroring the
 * `isPortfolioMetadataOnlyChange` rule in `helpers/shared.js`. A pure
 * `portfolio.metadata.updatedAt` flutter must never invalidate a fingerprint.
 *
 * @param {*} portfolio
 * @returns {*}
 */
function portfolioForFingerprint(portfolio) {
  if (!portfolio || typeof portfolio !== "object" || Array.isArray(portfolio)) {
    return portfolio === undefined ? null : portfolio;
  }
  const copy = {...portfolio};
  delete copy.metadata;
  return copy;
}

/**
 * v9.2.4 (D-1): the resume-review signal that participates in the fingerprint.
 *
 * Before v9.2.4 the ONLY way this signal existed was an `options.resumeData`
 * passthrough, so the resume-review trigger (which passed the freshly written
 * review) and every other caller (client bootstrap, profile trigger — which
 * passed nothing) computed DIFFERENT fingerprints for the same student state.
 * The stored fingerprint therefore thrashed between the two variants and the
 * v9.2.2 skip gate fired only about half the time.
 *
 * The resume-review trigger now PERSISTS the review signals onto
 * `portfolio.resume.latestMissingKeywords` / `latestATSScore` (the same
 * counter merge it already performs) and refreshes WITHOUT an options
 * passthrough. This helper derives the signal from the document so that every
 * caller — with or without an options passthrough — produces the SAME value.
 * That is what makes the stored fingerprint converge to one stable value.
 *
 * A user with no persisted review signal still yields `null`, exactly as
 * before, so no pre-existing fingerprint is gratuitously invalidated.
 *
 * @param {object} userData Raw `users/{uid}` document
 * @param {object} [options] `{resumeData}` passthrough (legacy callers)
 * @returns {{atsScore: (number|null), missingKeywords: Array<string>}|null}
 */
function resumeReviewSignal(userData, options) {
  const resumeData = options && options.resumeData ? options.resumeData : null;
  if (resumeData) {
    return {
      atsScore: resumeData.atsScore ?? null,
      missingKeywords: resumeData.missingKeywords || [],
    };
  }

  const portfolio =
      userData && typeof userData.portfolio === "object" &&
      !Array.isArray(userData.portfolio)
        ? userData.portfolio
        : null;
  const resume =
      portfolio && typeof portfolio.resume === "object" &&
      !Array.isArray(portfolio.resume)
        ? portfolio.resume
        : null;
  const storedKeywords =
      resume && Array.isArray(resume.latestMissingKeywords)
        ? resume.latestMissingKeywords
        : [];

  // No persisted review signal ⇒ identical to the pre-v9.2.4 `null`.
  if (storedKeywords.length === 0) return null;

  return {
    atsScore: resume && typeof resume.latestATSScore === "number"
      ? resume.latestATSScore
      : null,
    missingKeywords: storedKeywords,
  };
}

/**
 * Compute the canonical fingerprint of every input the recommendation engine
 * reads for one student. Pure and deterministic — exported so it is unit
 * testable without Firestore.
 *
 * @param {object} params
 * @param {object} params.userData Raw `users/{uid}` document
 * @param {object} [params.options] `{resumeData}` passthrough
 * @param {Array<string>} [params.candidateIds] ids of loaded candidates
 * @param {Set<string>|Array<string>} [params.appliedPlacementIds]
 * @returns {string} sha256 hex digest
 */
function computeRecommendationFingerprint({
  userData = {},
  options = {},
  candidateIds = [],
  appliedPlacementIds = [],
} = {}) {
  const applied = appliedPlacementIds instanceof Set
    ? [...appliedPlacementIds]
    : [...(appliedPlacementIds || [])];

  const signals = {
    v: RECOMMENDATION_ENGINE_VERSION,
    skills: userData.skills || [],
    careerInterest: userData.careerInterest ?? null,
    career: userData.career ?? null,
    department: userData.department ?? null,
    graduationYear: userData.graduationYear ?? null,
    academic: userData.academic ?? null,
    portfolio: portfolioForFingerprint(userData.portfolio),
    // v9.2.4 (D-1): derived from the document when no passthrough is given,
    // so every caller hashes the same resume-review signal.
    resumeReview: resumeReviewSignal(userData, options),
    applied: applied.slice().sort(),
    candidates: candidateIds.slice().sort(),
  };

  return crypto
      .createHash("sha256")
      .update(stableStringify(signals))
      .digest("hex");
}

/**
 * True when any ACTIVE recommendation document has already expired. Used to
 * never skip a regeneration while the materialized set would render empty for
 * the client (the client filters out expired rows).
 *
 * @param {FirebaseFirestore.QuerySnapshot} snapshot
 * @returns {boolean}
 */
function hasExpiredActiveRecommendation(snapshot) {
  const now = Date.now();
  return snapshot.docs.some((doc) => {
    const expiresAt = doc.get("expiresAt");
    return !!expiresAt &&
        typeof expiresAt.toMillis === "function" &&
        expiresAt.toMillis() <= now;
  });
}

// ===============================================
// EXPORTS
// ===============================================

/**
 * Client-callable entry point for refreshing recommendations.
 */
exports.refreshRecommendations = onCall(
    {maxInstances: 10, timeoutSeconds: 120},
    async (request) => {
      const userId = request.auth?.uid;
      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to refresh recommendations."
        );
      }

      // v9.2.2 (§2): an explicit client request may force a regeneration
      // (the student dashboard refresh button). Implicit callers omit it so
      // the fingerprint gate can collapse duplicates.
      const force = request.data?.force === true;

      try {
        const userDoc = await admin.firestore()
            .collection("users")
            .doc(userId)
            .get();
        if (!userDoc.exists) {
          throw new admin.functions.https.HttpsError(
              "not-found",
              "User profile not found."
          );
        }

        const result = await refreshRecommendationsForStudent(
            userId,
            userDoc.data(),
            {},
            {force}
        );
        return {success: true, skipped: result.skipped === true};
      } catch (error) {
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        console.error("refreshRecommendations error:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Could not refresh recommendations. Please try again later."
        );
      }
    }
);

/**
 * Loads up to `maxResults` documents from a Firestore query, paging through
 * the result set with a cursor (`startAfter`) instead of a single large
 * `.limit()`. Uses the implicit document-ID ordering, so `startAfter(lastDoc)`
 * advances past the final doc of the previous page. Stops early once the
 * collection is exhausted or the cap is reached.
 *
 * @param {FirebaseFirestore.Query} baseQuery A query with all `.where()`
 *   filters applied, no `.limit()`/`.orderBy()`.
 * @param {number} [maxResults] Cap on the total docs collected.
 * @param {number} [pageSize] Per-page size (bounded read).
 * @returns {Promise<Array<object>>} Docs as `{...data, id}`.
 */
async function loadCandidates(
    baseQuery,
    maxResults = RECOMMENDATION_CANDIDATE_MAX,
    pageSize = RECOMMENDATION_CANDIDATE_PAGE_SIZE
) {
  const docs = [];
  let lastDoc = null;
  while (docs.length < maxResults) {
    const query = lastDoc
        ? baseQuery.startAfter(lastDoc).limit(pageSize)
        : baseQuery.limit(pageSize);
    const snapshot = await query.get();
    if (snapshot.empty) break;
    for (const doc of snapshot.docs) {
      docs.push({...doc.data(), id: doc.id});
      if (docs.length >= maxResults) break;
    }
    if (snapshot.docs.length < pageSize) break; // exhausted
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
  }
  return docs;
}

/**
 * Engine orchestrator — loads candidate data, runs the deterministic engine,
 * enriches explanations, and persists the result.
 *
 * Called by the `refreshRecommendations` callable AND by the
 * `onProfileUpdatedRefreshAI` and `onResumeReviewCreatedRefreshMatches`
 * triggers.
 *
 * @param {string} userId
 * @param {object} userData Raw `users/{uid}` document
 * @param {object} [options] `{resumeData}` passthrough
 * @param {object} [refreshOptions] `{force}` — bypass the fingerprint skip
 * @returns {Promise<{skipped: boolean, fingerprint: string}>}
 */
async function refreshRecommendationsForStudent(
    userId,
    userData,
    options = {},
    refreshOptions = {}
) {
  const force = refreshOptions.force === true;

  const [
    alumniDocs,
    opportunityDocs,
    placementDocs,
    applicationSnapshot,
    existingSnapshot,
    metaSnapshot,
  ] = await Promise.all([
    loadCandidates(
        admin.firestore().collection("users")
            .where("role", "==", "alumni")
            .where("profileCompleted", "==", true)
    ),
    loadCandidates(
        admin.firestore().collection("opportunities")
            .where("isActive", "==", true)
    ),
    loadCandidates(
        admin.firestore().collection("placements")
            .where("isActive", "==", true)
    ),
    admin.firestore()
        .collection("applications")
        .where("userId", "==", userId)
        .get(),
    admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("recommendations")
        .where("isActive", "==", true)
        .get(),
    admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("recommendations_meta")
        .doc("summary")
        .get(),
  ]);

  const appliedPlacementIds = new Set(
      applicationSnapshot.docs.map((doc) => doc.data().placementId).filter(Boolean)
  );

  const candidateIds = [
    ...alumniDocs.map((doc) => doc.id),
    ...opportunityDocs.map((doc) => doc.id),
    ...placementDocs.map((doc) => doc.id),
  ];

  const fingerprint = computeRecommendationFingerprint({
    userData,
    options,
    candidateIds,
    appliedPlacementIds,
  });

  // v9.2.2 (§2): collapse duplicate regenerations for an unchanged state.
  const storedFingerprint =
      metaSnapshot.exists ? metaSnapshot.get("fingerprint") : null;
  const fingerprintUnchanged =
      typeof storedFingerprint === "string" &&
      storedFingerprint.length > 0 &&
      storedFingerprint === fingerprint;
  const hasMaterializedSet = !existingSnapshot.empty;
  const expired = hasExpiredActiveRecommendation(existingSnapshot);

  if (!force && fingerprintUnchanged && hasMaterializedSet && !expired) {
    console.log(
        `refreshRecommendationsForStudent: SKIPPED (fingerprint unchanged) ` +
        `user=${userId} active=${existingSnapshot.size}`
    );
    return {skipped: true, fingerprint};
  }

  const {recommendations, summary} = buildRecommendations({
    userId,
    userData,
    options,
    alumniDocs,
    opportunityDocs,
    placementDocs,
    appliedPlacementIds,
  });

  await enrichRecommendationExplanations(recommendations);

  const timestampNow = admin.firestore.Timestamp.now();
  const storedRecommendations = recommendations.map((r) => ({
    ...r,
    createdAt: r.createdAt instanceof Date
        ? admin.firestore.Timestamp.fromDate(r.createdAt)
        : r.createdAt || timestampNow,
    expiresAt: r.expiresAt instanceof Date
        ? admin.firestore.Timestamp.fromDate(r.expiresAt)
        : r.expiresAt || null,
  }));

  const regeneratedIds = new Set(storedRecommendations.map((r) => r.id));

  const batch = admin.firestore().batch();
  for (const oldDoc of existingSnapshot.docs) {
    if (!regeneratedIds.has(oldDoc.id)) {
      batch.delete(oldDoc.ref);
    }
  }
  for (const recommendation of storedRecommendations) {
    const docRef = admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("recommendations")
        .doc(recommendation.id);
    batch.set(docRef, recommendation, {merge: true});
  }

  const metaRef = admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("recommendations_meta")
      .doc("summary");
  batch.set(metaRef, {
    updatedAt: admin.firestore.Timestamp.now(),
    total: storedRecommendations.length,
    // v9.2.2 (§2): the input fingerprint this materialized set corresponds to.
    fingerprint,
    ...summary,
  }, {merge: true});

  await batch.commit();

  console.log(
      `refreshRecommendationsForStudent: REGENERATED user=${userId} ` +
      `total=${storedRecommendations.length} ` +
      `(alumni=${alumniDocs.length} opportunities=${opportunityDocs.length} ` +
      `placements=${placementDocs.length} applied=${appliedPlacementIds.size})`
  );

  const bestMentor = storedRecommendations.find((r) => r.type === "mentor");
  const bestJob = storedRecommendations.find((r) => r.type === "job");
  if (bestMentor) {
    await maybeCreateNotification(userId, "mentorMatch", {
      title: "New Mentor Match",
      body: `${bestMentor.title} (${bestMentor.score}% match)`,
      data: {
        alumniId: bestMentor.metadata && bestMentor.metadata.alumniId,
        matchScore: bestMentor.score,
      },
      priority: "high",
    });
  }
  if (bestJob) {
    await maybeCreateNotification(userId, "jobMatch", {
      title: "New Job Match",
      body: `${bestJob.title} (${bestJob.score}% match)`,
      data: {
        opportunityId: bestJob.opportunityId || (bestJob.metadata && bestJob.metadata.opportunityId),
        matchScore: bestJob.score,
      },
      priority: "high",
    });
  }

  return {skipped: false, fingerprint};
}

module.exports = {
  refreshRecommendations: exports.refreshRecommendations,
  refreshRecommendationsForStudent,
  computeRecommendationFingerprint,
};
