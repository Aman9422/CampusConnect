/**
 * CampusConnect — AI Chat (askAI) Cloud Function + helpers.
 *
 * Handles the AI assistant chat flow:
 *   - Rate limiting (per-minute)
 *   - Spam detection (repeated messages)
 *   - Usage tracking (daily count, 24 h reset)
 *   - Trial management (5-day free trial)
 *   - AI provider call (Groq → HuggingFace fallback)
 *   - Dual storage (ai_conversations + users/{uid}/ai_interactions)
 *
 * Extracted from `index.js` (v9.0 ARCH-2 refactor).
 */

const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {generateChatResponse} = require("./aiProvider");
const {sanitizeAIInput, logAnalyticsEvent} = require("../helpers/shared");
// v9.0 (IMP-15): unified AI quota — `ai_usage/{uid}` is now a legacy mirror;
// the authoritative store is `user_ai_quotas/{uid}.chat`.
const quota = require("./quota");

// ===============================================
// CONSTANTS
// ===============================================

const DAILY_MESSAGE_LIMIT = 50; // Soft limit for abuse prevention
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const RATE_LIMIT_MAX_MESSAGES = 5; // Max 5 messages per minute
const TRIAL_DURATION_DAYS = 5;
const MIN_MESSAGE_LENGTH = 1;
const MAX_MESSAGE_LENGTH = 1000;

// ===============================================
// EXPORTS
// ===============================================

/**
 * AI Assistant Cloud Function (Version 4)
 *
 * This function acts as a gateway between the Flutter app and AI services.
 * It receives user messages and returns AI-generated responses.
 *
 * VERSION 4 Features:
 * - Usage tracking (messages per day)
 * - 5-day free trial management
 * - AI guardrails (rate limiting, spam detection)
 * - Analytics event logging
 * - Stability improvements
 *
 * v8.4.2 (S6b/P3): CALLABLE (was HTTPS onRequest). The authenticated uid
 * comes from `request.auth.uid` — a forged body `userId` can no longer spend
 * AI quota on another user's account. Calls return the same JSON shape.
 */
exports.askAI = onCall(
    // v8.8.3 (HIGH-1): the Groq(30 s)→HF(60 s) fallback chain can need up to
    // 90 s; the default 60 s callable timeout killed the chat fallback
    // mid-flight — bump to 120 s (matches reviewResume/deleteAIHistory).
    {maxInstances: 10, timeoutSeconds: 120},
    async (request) => {
      // v8.4.2 (S6b/P3): the authenticated uid from Firebase Auth is the
      // only identity source — body/query `userId` is no longer trusted.
      const userId = request.auth?.uid;

      if (!userId) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "You must be logged in to use the AI assistant."
        );
      }

      try {
        // Extract data from request
        const {message} = request.data || {};

        // Validate required fields
        if (!message) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              "Missing required field: message"
          );
        }

        // Validate message is not empty or too long
        const trimmedMessage = message.trim();
        if (trimmedMessage.length < MIN_MESSAGE_LENGTH) {
          return {
            response: "Please enter a message to chat with me! 😊",
            warning: "empty_message",
          };
        }

        if (trimmedMessage.length > MAX_MESSAGE_LENGTH) {
          return {
            response: "Your message is a bit too long! " +
                     "Please keep it under 1000 characters so I can help you better. 📝",
            warning: "message_too_long",
          };
        }

        // Log the interaction (for analytics/debugging)
        console.log(`AI Request from user: ${userId}`);
        console.log(`Message: ${trimmedMessage.substring(0, 50)}...`);

        // ===============================================
        // VERSION 4: RATE LIMITING & SPAM DETECTION
        // ===============================================
        const rateLimitCheck = await checkRateLimit(userId);
        if (!rateLimitCheck.allowed) {
          return {
            response: "Whoa, slow down there! 🐢\n\n" +
                     "You're sending messages a bit too quickly. " +
                     "Take a moment to breathe, and try again in a minute. " +
                     "I'll be here waiting to help!",
            warning: "rate_limited",
            retryAfter: rateLimitCheck.retryAfter,
          };
        }

        // Check for spam (repeated identical messages)
        const spamCheck = await checkForSpam(userId, trimmedMessage);
        if (!spamCheck.allowed) {
          return {
            response: "I noticed you're sending the same message repeatedly. 🔁\n\n" +
                     "If you're having trouble, try rephrasing your question or " +
                     "asking something different. I'm here to help with all your " +
                     "questions about academics, placements, and career guidance!",
            warning: "spam_detected",
          };
        }

        // ===============================================
        // VERSION 4: USAGE TRACKING
        // ===============================================
        const usageData = await trackUsage(userId);

        // Soft limit check (don't block, just warn)
        if (usageData.dailyCount >= DAILY_MESSAGE_LIMIT) {
          console.log(`User ${userId} exceeded daily limit: ${usageData.dailyCount}`);
          // Continue processing but log for monitoring
        }

        // ===============================================
        // VERSION 4: TRIAL MANAGEMENT
        // ===============================================
        const trialInfo = await manageUserTrial(userId);

        // ===============================================
        // VERSION 4: ANALYTICS EVENT LOGGING
        // ===============================================
        await logAnalyticsEvent({
          eventType: "ai_message_sent",
          userId: userId,
          metadata: {
            messageLength: trimmedMessage.length,
            dailyUsageCount: usageData.dailyCount,
            trialStatus: trialInfo.status,
          },
        });

        // IMP-11: store in the modern per-user path only (ai_conversations
        // writes removed — legacy data has expired).
        await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("ai_interactions")
            .add({
              role: "user",
              message: trimmedMessage,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              status: "processed",
              dailyUsageCount: usageData.dailyCount,
            });

        // ===============================================
        // AI RESPONSE LOGIC (Real AI via Groq/HuggingFace)
        // ===============================================
        // v9.0 (IMP-12): sanitize user input before sending to AI —
        // strips control characters and zero-width Unicode to prevent
        // invisible instruction injection.
        const sanitizedMessage = sanitizeAIInput(trimmedMessage);
        let aiResponse;
        try {
          const aiResult = await generateChatResponse(sanitizedMessage);
          aiResponse = aiResult.response;
          console.log(`AI chat response from provider: ${aiResult.providerUsed}`);
        } catch (aiError) {
          console.error("AI provider error in askAI:", aiError);
          aiResponse = "I'm having a bit of trouble thinking right now. 🤔\n\n" +
                       "Please try again in a moment. If this persists, " +
                       "the AI service may be temporarily unavailable.";
        }

        // IMP-11: store AI response in the modern per-user path only.
        await admin.firestore()
            .collection("users")
            .doc(userId)
            .collection("ai_interactions")
            .add({
              role: "assistant",
              message: aiResponse,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              isAIResponse: true,
              status: "delivered",
            });

        // ===============================================
        // VERSION 4: ANALYTICS EVENT LOGGING
        // ===============================================
        await logAnalyticsEvent({
          eventType: "ai_response_received",
          userId: userId,
          metadata: {
            responseLength: aiResponse.length,
            trialStatus: trialInfo.status,
          },
        });

        // Return successful response with VERSION 4 metadata
        return {
          response: aiResponse,
          timestamp: new Date().toISOString(),
          // VERSION 4: Trial information (for informational display only)
          trial: {
            status: trialInfo.status, // "active", "expired", or "none"
            daysRemaining: trialInfo.daysRemaining,
            expiresAt: trialInfo.expiresAt,
          },
          // VERSION 4: Usage information (for informational display only)
          usage: {
            dailyCount: usageData.dailyCount,
            dailyLimit: DAILY_MESSAGE_LIMIT,
            lastResetAt: usageData.lastResetAt,
          },
        };
      } catch (error) {
        console.error("Error in askAI function:", error);
        throw new admin.functions.https.HttpsError(
            "internal",
            "Internal server error. Please try again later."
        );
      }
    }
);

// ===============================================
// PRIVATE HELPERS
// ===============================================

/**
 * Track AI message usage per user (VERSION 4)
 *
 * Stores daily message count and resets every 24 hours.
 * This is for backend monitoring and soft abuse prevention.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Usage data {dailyCount, lastResetAt}
 */
async function trackUsage(userId) {
  // v9.0 (IMP-15): delegate to the unified quota store. `incrementDailyUsage`
  // writes BOTH `user_ai_quotas/{uid}.chat` (authoritative) and the legacy
  // `ai_usage/{uid}` mirror atomically, and returns `{dailyCount, lastResetAt}`
  // exactly as the old implementation did (ISO `lastResetAt`). Behavior is
  // unchanged: 24h reset, soft 50/day limit, first-use starts at 1.
  return quota.incrementDailyUsage(userId, "chat");
}

/**
 * Manage user's 5-day free trial (VERSION 4)
 *
 * Creates trial on first AI usage and tracks expiration.
 * Returns trial status but does NOT block access (soft enforcement).
 *
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Trial info {status, daysRemaining, expiresAt}
 */
async function manageUserTrial(userId) {
  const userRef = admin.firestore()
      .collection("users")
      .doc(userId);

  const now = admin.firestore.Timestamp.now();

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      if (!userDoc.exists) {
        // New user - create with trial
        const trialStartsAt = now;
        const trialExpiresAt = admin.firestore.Timestamp.fromMillis(
            now.toMillis() + (TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000)
        );

        transaction.set(userRef, {
          aiTrialStartedAt: trialStartsAt,
          aiTrialExpiresAt: trialExpiresAt,
          createdAt: now,
        }, {merge: true});

        return {
          status: "active",
          daysRemaining: TRIAL_DURATION_DAYS,
          expiresAt: trialExpiresAt.toDate().toISOString(),
        };
      }

      const userData = userDoc.data();

      // Check if trial already exists
      if (!userData.aiTrialStartedAt) {
        // User exists but no trial - create it
        const trialStartsAt = now;
        const trialExpiresAt = admin.firestore.Timestamp.fromMillis(
            now.toMillis() + (TRIAL_DURATION_DAYS * 24 * 60 * 60 * 1000)
        );

        transaction.update(userRef, {
          aiTrialStartedAt: trialStartsAt,
          aiTrialExpiresAt: trialExpiresAt,
        });

        return {
          status: "active",
          daysRemaining: TRIAL_DURATION_DAYS,
          expiresAt: trialExpiresAt.toDate().toISOString(),
        };
      }

      // Trial exists - check if expired
      const expiresAt = userData.aiTrialExpiresAt;
      const msRemaining = expiresAt.toMillis() - now.toMillis();
      const daysRemaining = Math.ceil(msRemaining / (24 * 60 * 60 * 1000));

      if (msRemaining <= 0) {
        // Trial expired
        return {
          status: "expired",
          daysRemaining: 0,
          expiresAt: expiresAt.toDate().toISOString(),
        };
      }

      // Trial active
      return {
        status: "active",
        daysRemaining: Math.max(0, daysRemaining),
        expiresAt: expiresAt.toDate().toISOString(),
      };
    });

    return result;
  } catch (error) {
    console.error("Error managing trial:", error);
    // Return safe defaults if trial management fails
    return {
      status: "none",
      daysRemaining: 0,
      expiresAt: null,
    };
  }
}

/**
 * Check rate limiting to prevent spam (VERSION 4)
 *
 * Limits messages per time window to prevent abuse.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} {allowed: boolean, retryAfter: number}
 */
async function checkRateLimit(userId) {
  const rateLimitRef = admin.firestore()
      .collection("ai_rate_limits")
      .doc(userId);

  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);

      if (!doc.exists) {
        // First message - allow
        transaction.set(rateLimitRef, {
          timestamps: [now],
          lastCleanup: now,
        });
        return {allowed: true, retryAfter: 0};
      }

      const data = doc.data();
      let timestamps = data.timestamps || [];

      // Remove old timestamps outside window
      timestamps = timestamps.filter((ts) => ts > windowStart);

      if (timestamps.length >= RATE_LIMIT_MAX_MESSAGES) {
        // Rate limit exceeded
        const oldestTimestamp = Math.min(...timestamps);
        const retryAfter = Math.ceil((oldestTimestamp + RATE_LIMIT_WINDOW_MS - now) / 1000);
        return {allowed: false, retryAfter};
      }

      // Add current timestamp and update
      timestamps.push(now);
      transaction.update(rateLimitRef, {
        timestamps,
        lastCleanup: now,
      });

      return {allowed: true, retryAfter: 0};
    });

    return result;
  } catch (error) {
    console.error("Error checking rate limit:", error);
    // On error, allow the request (fail open)
    return {allowed: true, retryAfter: 0};
  }
}

/**
 * Check for spam (repeated identical messages) (VERSION 4)
 *
 * Detects when users send the same message repeatedly.
 *
 * @param {string} userId - User's Firebase Auth ID
 * @param {string} message - Current message
 * @return {object} {allowed: boolean}
 */
async function checkForSpam(userId, message) {
  const spamCheckRef = admin.firestore()
      .collection("ai_spam_check")
      .doc(userId);

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(spamCheckRef);

      if (!doc.exists) {
        // First message - allow
        transaction.set(spamCheckRef, {
          lastMessage: message,
          repeatCount: 1,
          lastUpdated: Date.now(),
        });
        return {allowed: true};
      }

      const data = doc.data();
      const timeSinceLastMessage = Date.now() - data.lastUpdated;

      // If same message within 5 minutes
      if (data.lastMessage === message && timeSinceLastMessage < 300000) {
        const newRepeatCount = data.repeatCount + 1;

        if (newRepeatCount >= 3) {
          // Spam detected (3+ identical messages in 5 minutes)
          transaction.update(spamCheckRef, {
            repeatCount: newRepeatCount,
            lastUpdated: Date.now(),
          });
          return {allowed: false};
        }

        transaction.update(spamCheckRef, {
          repeatCount: newRepeatCount,
          lastUpdated: Date.now(),
        });
        return {allowed: true};
      }

      // Different message or enough time passed - reset
      transaction.update(spamCheckRef, {
        lastMessage: message,
        repeatCount: 1,
        lastUpdated: Date.now(),
      });
      return {allowed: true};
    });

    return result;
  } catch (error) {
    console.error("Error checking spam:", error);
    // On error, allow the request (fail open)
    return {allowed: true};
  }
}
