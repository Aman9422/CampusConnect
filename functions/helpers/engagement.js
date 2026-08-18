/**
 * CampusConnect — Engagement scoring utilities.
 *
 * Computes engagement scores, streaks, profile strength, and badges for
 * the daily recompute scheduler and the profile-update trigger.
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const admin = require("firebase-admin");
const {maybeCreateNotification} = require("./shared");

// ===============================================
// ENGAGEMENT SUMMARY
// ===============================================

/**
 * Recompute a user's engagement summary from their activity history.
 *
 * Reads up to the 250 most recent activities, computes:
 *   - activityPoints (sum of all points)
 *   - dailyStreak (consecutive days with activity)
 *   - profileStrength (0–100 based on 12 profile fields)
 *   - engagementScore (blended metric)
 *   - badges (4 badges, each with progress/target/earnedAt)
 *
 * Writes the result to `users/{uid}/engagement_summary/summary`.
 */
async function recomputeEngagementSummary(userId, userData) {
  const activitySnapshot = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("activities")
      .orderBy("occurredAt", "desc")
      .limit(250)
      .get();

  const activities = activitySnapshot.docs.map((doc) => doc.data());
  const activityPoints = activities.reduce((sum, item) => sum + (item.points || 0), 0);
  const dailyStreak = computeStreakFromActivities(activities);
  const profileStrength = computeProfileStrength(userData);
  const engagementScore = Math.min(
      100,
      Math.round(profileStrength * 0.6 + Math.min(40, activityPoints * 0.4) + Math.min(20, dailyStreak * 2.5))
  );

  // v8.7.1: role-aware activity badge. Alumni see "Active Alumni" — "Active
  // Student" is a Student-flavored title and looked wrong on the Alumni
  // dashboard (user report). Mirrors the client rule exactly so the badge
  // never flickers between writers (same class as the v8.6 threshold fix).
  const activeTitle = userData.role === "alumni" ? "Active Alumni" : "Active Student";
  const activeDescription = userData.role === "alumni"
      ? "Stay active and engaged in the alumni community"
      : "Earn 50 engagement points";

  const badges = [
    // v8.6 (LOW): threshold aligned with the client badge logic (earned at
    // profile strength >= 85) — previously the server required 100 while the
    // client showed the badge at 85, so the badge flickered between sources.
    buildBadge("profile_pro", "profilePro", "Profile Pro", "Complete profile for stronger matches", profileStrength, 85),
    buildBadge("consistency_champion", "consistencyChampion", "Consistency Champion", "Stay active 7 days in a row", dailyStreak, 7),
    buildBadge("active_student", "activeStudent", activeTitle, activeDescription, activityPoints, 50),
    buildBadge("networking_pro", "networkingPro", "Networking Pro", "Build strong networking activity", activityPoints, 100),
  ];

  await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("engagement_summary")
      .doc("summary")
      .set({
        engagementScore,
        profileStrength,
        dailyStreak,
        activityPoints,
        badges,
        updatedAt: admin.firestore.Timestamp.now(),
        lastActiveAt: activities.length > 0 ? activities[0].occurredAt : null,
      }, {merge: true});

  if (dailyStreak > 0 && dailyStreak % 7 === 0) {
    await maybeCreateNotification(userId, "engagementMilestone", {
      title: "Engagement Milestone",
      body: `Great momentum! You are on a ${dailyStreak}-day streak.`,
      data: {streakDays: dailyStreak},
      priority: "medium",
    });
  }
}

// ===============================================
// BADGE BUILDER
// ===============================================

function buildBadge(id, type, title, description, progress, target) {
  const earned = progress >= target;
  return {
    id,
    type,
    title,
    description,
    icon: "emoji_events",
    progress,
    target,
    isFeatured: id === "profile_pro" || id === "consistency_champion",
    earnedAt: earned ? admin.firestore.Timestamp.now() : null,
  };
}

// ===============================================
// STREAK COMPUTATION
// ===============================================

function computeStreakFromActivities(activities) {
  if (!activities || activities.length === 0) return 0;
  const days = new Set(
      activities
          .map((a) => a.occurredAt && a.occurredAt.toDate ? a.occurredAt.toDate() : null)
          .filter(Boolean)
          .map((d) => `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`)
  );
  const now = new Date();
  let streak = 0;
  let cursor = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  while (days.has(`${cursor.getUTCFullYear()}-${cursor.getUTCMonth() + 1}-${cursor.getUTCDate()}`)) {
    streak++;
    cursor = new Date(cursor.getTime() - 24 * 60 * 60 * 1000);
  }
  return streak;
}

// ===============================================
// PROFILE STRENGTH
// ===============================================

function computeProfileStrength(userData) {
  let completed = 0;
  const total = 12;
  if ((userData.personal?.fullName || "").trim()) completed++;
  if ((userData.personal?.phone || "").trim()) completed++;
  if ((userData.personal?.bio || "").trim()) completed++;
  if ((userData.academic?.college || "").trim()) completed++;
  if ((userData.academic?.program || "").trim()) completed++;
  if ((userData.academic?.year || 0) > 0) completed++;
  if ((userData.academic?.cgpa || 0) > 0) completed++;
  if ((userData.skills || []).length > 0) completed++;
  if ((userData.careerInterest || "").trim()) completed++;
  if ((userData.company || "").trim()) completed++;
  if ((userData.jobRole || "").trim()) completed++;
  if ((userData.linkedinProfile || "").trim()) completed++;
  return Math.round((completed / total) * 100);
}

module.exports = {
  recomputeEngagementSummary,
  buildBadge,
  computeStreakFromActivities,
  computeProfileStrength,
};
