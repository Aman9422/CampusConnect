/**
 * CampusConnect — Cloud Functions Entry Point (v9.0 ARCH-2 refactor).
 *
 * This file is a thin entry point that:
 *   1. Initialises the Firebase Admin SDK (once).
 *   2. Requires every module that registers Cloud Function exports.
 *   3. Re-exports every Cloud Function so the Firebase CLI can discover
 *      and deploy them.
 *
 * All business logic lives in the extracted modules:
 *   - careerCoach.js        — Career Coach callable + quota + cache
 *   - ai/chat.js            — askAI + rate limiting + spam detection
 *   - ai/resumeReview.js    — reviewResume + PDF extraction + quota
 *   - ai/deepAnalysis.js    — generateResumeAnalysis + AI analysis quota
 *   - ai/chatDelete.js      — deleteAIHistory + retention cleanup
 *   - triggers/             — all Firestore triggers
 *   - schedulers/           — all scheduled functions
 *   - recommendations/      — engine, refresh, AI explanations, career roles
 *   - helpers/              — shared utilities (analytics, notifications, engagement)
 */

const admin = require("firebase-admin");

// ── Admin SDK init (must happen before any module that uses `admin`) ──
admin.initializeApp();

// ── AI Career Coach (v9.0) ──────────────────────────────────────────────
const careerCoach = require("./careerCoach");

// ── AI Chat ─────────────────────────────────────────────────────────────
const chat = require("./ai/chat");

// ── AI Resume Review ────────────────────────────────────────────────────
const resumeReview = require("./ai/resumeReview");

// ── AI Deep Analysis ────────────────────────────────────────────────────
const deepAnalysis = require("./ai/deepAnalysis");

// ── AI Chat Deletion + Retention ────────────────────────────────────────
const chatDelete = require("./ai/chatDelete");

// ── Firestore Triggers ──────────────────────────────────────────────────
const triggers = require("./triggers");

// ── Scheduled Functions ─────────────────────────────────────────────────
const schedulers = require("./schedulers");

// ── Recommendations (callable + engine orchestrator) ─────────────────────
const recommendationsRefresh = require("./recommendations/refresh");

// ── Placement analytics (SEC-1: both migrated to onCall) ────────────────
const placements = require("./placements");

// ────────────────────────────────────────────────────────────────────────
// Re-export every Cloud Function for Firebase CLI discovery & deployment.
// Each key becomes a deployed function name.
// ────────────────────────────────────────────────────────────────────────

// Career Coach
exports.generateCareerCoachAnalysis = careerCoach.generateCareerCoachAnalysis;
exports.compensateStaleCareerCoachQuota = careerCoach.compensateStaleCareerCoachQuota;

// AI Chat
exports.askAI = chat.askAI;

// AI Resume Review
exports.reviewResume = resumeReview.reviewResume;
exports.compensateStaleResumeQuota = resumeReview.compensateStaleResumeQuota;

// AI Deep Analysis
exports.generateResumeAnalysis = deepAnalysis.generateResumeAnalysis;
exports.compensateStaleAIAnalysisQuota = deepAnalysis.compensateStaleAIAnalysisQuota;

// AI Chat Deletion + Retention
exports.deleteAIHistory = chatDelete.deleteAIHistory;
exports.cleanupExpiredAIConversations = chatDelete.cleanupExpiredAIConversations;

// Firestore Triggers
exports.onProfileUpdatedRefreshAI = triggers.onProfileUpdatedRefreshAI;
exports.onResumeReviewCreatedRefreshMatches = triggers.onResumeReviewCreatedRefreshMatches;
exports.onOpportunityPostedNotifyStudents = triggers.onOpportunityPostedNotifyStudents;
exports.onMentorshipRequestCreated = triggers.onMentorshipRequestCreated;
exports.onMentorshipRequestResponseNotifyStudent = triggers.onMentorshipRequestResponseNotifyStudent;
exports.onChatMessageCreated = triggers.onChatMessageCreated;

// Scheduled Functions
exports.autoExpireOpportunities = schedulers.autoExpireOpportunities;
exports.sendInactivityReminders = schedulers.sendInactivityReminders;
exports.recomputeEngagementScores = schedulers.recomputeEngagementScores;

// Recommendations
exports.refreshRecommendations = recommendationsRefresh.refreshRecommendations;

// Placement Analytics (SEC-1: both onCall — identity from request.auth.uid)
exports.logPlacementView = placements.logPlacementView;
exports.logPlacementApplication = placements.logPlacementApplication;
