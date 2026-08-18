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
 * Engine orchestrator — loads candidate data, runs the deterministic engine,
 * enriches explanations, and persists the result.
 *
 * Called by the `refreshRecommendations` callable AND by the
 * `onProfileUpdatedRefreshAI` and `onResumeReviewCreatedRefreshMatches`
 * triggers.
 */
async function refreshRecommendationsForStudent(userId, userData, options = {}) {
  const [alumniSnapshot, opportunitiesSnapshot, placementsSnapshot, applicationsSnapshot] =
      await Promise.all([
        admin.firestore()
            .collection("users")
            .where("role", "==", "alumni")
            .where("profileCompleted", "==", true)
            .limit(120)
            .get(),
        admin.firestore()
            .collection("opportunities")
            .where("isActive", "==", true)
            .limit(120)
            .get(),
        admin.firestore()
            .collection("placements")
            .where("isActive", "==", true)
            .limit(120)
            .get(),
        admin.firestore()
            .collection("applications")
            .where("userId", "==", userId)
            .get(),
      ]);

  const alumniDocs = alumniSnapshot.docs.map((doc) => ({...doc.data(), id: doc.id}));
  const opportunityDocs = opportunitiesSnapshot.docs.map((doc) => ({...doc.data(), id: doc.id}));
  const placementDocs = placementsSnapshot.docs.map((doc) => ({...doc.data(), id: doc.id}));
  const appliedPlacementIds = new Set(
      applicationsSnapshot.docs.map((doc) => doc.data().placementId).filter(Boolean)
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
