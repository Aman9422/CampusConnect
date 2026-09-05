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
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
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

        await refreshRecommendationsForStudent(userId, userDoc.data());
        return {success: true};
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
 */
async function refreshRecommendationsForStudent(userId, userData, options = {}) {
  const [alumniDocs, opportunityDocs, placementDocs, applicationSnapshot] =
      await Promise.all([
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
      ]);

  const appliedPlacementIds = new Set(
      applicationSnapshot.docs.map((doc) => doc.data().placementId).filter(Boolean)
  );

  console.log(
      `refreshRecommendationsForStudent: user=${userId} candidates=` +
      `alumni=${alumniDocs.length} opportunities=${opportunityDocs.length} ` +
      `placements=${placementDocs.length} applied=${appliedPlacementIds.size}`
  );

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

  const existingSnapshot = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("recommendations")
      .where("isActive", "==", true)
      .get();

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
    ...summary,
  }, {merge: true});

  await batch.commit();

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
}

module.exports = {
  refreshRecommendations: exports.refreshRecommendations,
  refreshRecommendationsForStudent,
};
