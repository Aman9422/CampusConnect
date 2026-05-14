const {onRequest, onCall} = require("firebase-functions/v2/https");
const {onDocumentWritten, onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const { generateAIResponse, generateChatResponse, generateResumeReviewAI } = require("./ai/aiProvider");

admin.initializeApp();

// ===============================================
// VERSION 4 CONSTANTS
// ===============================================
const DAILY_MESSAGE_LIMIT = 50; // Soft limit for abuse prevention
const RATE_LIMIT_WINDOW_MS = 60000; // 1 minute
const RATE_LIMIT_MAX_MESSAGES = 5; // Max 5 messages per minute
const TRIAL_DURATION_DAYS = 5;
const MIN_MESSAGE_LENGTH = 1;
const MAX_MESSAGE_LENGTH = 1000;

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
 * @param {object} request - Contains userId and message
 * @param {object} response - Returns AI response with trial/usage metadata
 */
exports.askAI = onRequest(
    {cors: true, maxInstances: 10},
    async (request, response) => {
      // Validate request method
      if (request.method !== "POST") {
        return response.status(405).json({
          error: "Method not allowed. Use POST.",
        });
      }

      try {
        // Extract data from request
        const {userId, message} = request.body;

        // Validate required fields
        if (!userId || !message) {
          return response.status(400).json({
            error: "Missing required fields: userId and message",
          });
        }

        // Validate message is not empty or too long
        const trimmedMessage = message.trim();
        if (trimmedMessage.length < MIN_MESSAGE_LENGTH) {
          return response.status(200).json({
            response: "Please enter a message to chat with me! 😊",
            warning: "empty_message",
          });
        }

        if (trimmedMessage.length > MAX_MESSAGE_LENGTH) {
          return response.status(200).json({
            response: "Your message is a bit too long! " +
                     "Please keep it under 1000 characters so I can help you better. 📝",
            warning: "message_too_long",
          });
        }

        // Log the interaction (for analytics/debugging)
        console.log(`AI Request from user: ${userId}`);
        console.log(`Message: ${trimmedMessage.substring(0, 50)}...`);

        // ===============================================
        // VERSION 4: RATE LIMITING & SPAM DETECTION
        // ===============================================
        const rateLimitCheck = await checkRateLimit(userId);
        if (!rateLimitCheck.allowed) {
          return response.status(200).json({
            response: "Whoa, slow down there! 🐢\n\n" +
                     "You're sending messages a bit too quickly. " +
                     "Take a moment to breathe, and try again in a minute. " +
                     "I'll be here waiting to help!",
            warning: "rate_limited",
            retryAfter: rateLimitCheck.retryAfter,
          });
        }

        // Check for spam (repeated identical messages)
        const spamCheck = await checkForSpam(userId, trimmedMessage);
        if (!spamCheck.allowed) {
          return response.status(200).json({
            response: "I noticed you're sending the same message repeatedly. 🔁\n\n" +
                     "If you're having trouble, try rephrasing your question or " +
                     "asking something different. I'm here to help with all your " +
                     "questions about academics, placements, and career guidance!",
            warning: "spam_detected",
          });
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

        // Store message in Firestore for history
        await admin.firestore()
            .collection("ai_conversations")
            .add({
              userId: userId,
              message: trimmedMessage,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              status: "processed",
              dailyUsageCount: usageData.dailyCount,
            });

        // ===============================================
        // AI RESPONSE LOGIC (Real AI via Groq/HuggingFace)
        // ===============================================
        let aiResponse;
        try {
          const aiResult = await generateChatResponse(trimmedMessage);
          aiResponse = aiResult.response;
          console.log(`AI chat response from provider: ${aiResult.providerUsed}`);
        } catch (aiError) {
          console.error("AI provider error in askAI:", aiError);
          aiResponse = "I'm having a bit of trouble thinking right now. 🤔\n\n" +
                       "Please try again in a moment. If this persists, " +
                       "the AI service may be temporarily unavailable.";
        }

        // Store AI response in Firestore
        await admin.firestore()
            .collection("ai_conversations")
            .add({
              userId: userId,
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
        return response.status(200).json({
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
        });
      } catch (error) {
        console.error("Error in askAI function:", error);
        return response.status(500).json({
          error: "Internal server error. Please try again later.",
        });
      }
    }
);

// ===============================================
// VERSION 4: HELPER FUNCTIONS
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
  const usageRef = admin.firestore()
      .collection("ai_usage")
      .doc(userId);

  const now = admin.firestore.Timestamp.now();
  const oneDayAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - (24 * 60 * 60 * 1000)
  );

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);

      if (!usageDoc.exists) {
        // First time user - create usage document
        const newUsageData = {
          dailyCount: 1,
          lastUsedAt: now,
          lastResetAt: now,
        };
        transaction.set(usageRef, newUsageData);
        return newUsageData;
      }

      const data = usageDoc.data();
      const lastResetAt = data.lastResetAt;

      // Check if we need to reset the counter (24 hours passed)
      if (lastResetAt.toMillis() < oneDayAgo.toMillis()) {
        // Reset counter
        const resetData = {
          dailyCount: 1,
          lastUsedAt: now,
          lastResetAt: now,
        };
        transaction.update(usageRef, resetData);
        return resetData;
      } else {
        // Increment counter
        const updatedData = {
          dailyCount: data.dailyCount + 1,
          lastUsedAt: now,
          lastResetAt: lastResetAt, // Keep existing reset time
        };
        transaction.update(usageRef, updatedData);
        return updatedData;
      }
    });

    return {
      dailyCount: result.dailyCount,
      lastResetAt: result.lastResetAt.toDate().toISOString(),
    };
  } catch (error) {
    console.error("Error tracking usage:", error);
    // Return safe defaults if tracking fails
    return {
      dailyCount: 1,
      lastResetAt: now.toDate().toISOString(),
    };
  }
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

/**
 * Log analytics events to Firestore (VERSION 4)
 * 
 * Stores events for tracking AI usage, placements, and other activities.
 * 
 * @param {object} eventData - Event data {eventType, userId, metadata}
 * @return {Promise<void>}
 */
async function logAnalyticsEvent(eventData) {
  try {
    await admin.firestore()
        .collection("analytics_events")
        .add({
          ...eventData,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
  } catch (error) {
    // Don't fail the request if analytics logging fails
    console.error("Error logging analytics event:", error);
  }
}

// ===============================================
// VERSION 4: PLACEMENT ANALYTICS FUNCTIONS
// ===============================================

/**
 * Log placement view event (VERSION 4)
 * Call this from placement viewing logic
 */
exports.logPlacementView = onRequest(
    {cors: true},
    async (request, response) => {
      if (request.method !== "POST") {
        return response.status(405).json({error: "Method not allowed"});
      }

      try {
        const {userId, placementId, company} = request.body;

        if (!userId || !placementId) {
          return response.status(400).json({
            error: "Missing required fields",
          });
        }

        await logAnalyticsEvent({
          eventType: "placement_viewed",
          userId,
          metadata: {
            placementId,
            company,
          },
        });

        return response.status(200).json({success: true});
      } catch (error) {
        console.error("Error logging placement view:", error);
        return response.status(500).json({error: "Internal server error"});
      }
    }
);

/**
 * Log placement application event and create application record (V5)
 * 
 * V5 Features:
 * - HTTPS Callable (secure auth context)
 * - Idempotent (safe to call multiple times)
 * - Duplicate prevention via Firestore transaction
 * - Returns existing application if already applied
 * - Dual storage for backward compatibility
 * - Analytics logging
 * 
 * Security: uid extracted from Firebase Auth (cannot be spoofed)
 */
exports.logPlacementApplication = onCall(
    {cors: false},
    async (request) => {
      // Extract uid from Firebase Auth context
      const uid = request.auth?.uid;
      
      if (!uid) {
        throw new admin.functions.https.HttpsError(
            "unauthenticated",
            "User must be logged in to apply"
        );
      }

      try {
        const {placementId, resumeUrl, company} = request.data;

        // Validate required fields
        if (!placementId) {
          throw new admin.functions.https.HttpsError(
              "invalid-argument",
              "Missing required field: placementId"
          );
        }

        // V5: Idempotent application creation
        const applicationId = `${uid}_${placementId}`;
        let isNewApplication = false;

        await admin.firestore().runTransaction(async (transaction) => {
          // Check if application already exists
          const existingAppRef = admin.firestore()
              .collection("applications")
              .doc(applicationId);
          
          const existingApp = await transaction.get(existingAppRef);

          if (existingApp.exists) {
            // Already applied - return success (idempotent behavior)
            isNewApplication = false;
            return;
          }

          // Create new application in top-level collection
          transaction.set(existingAppRef, {
            userId: uid,
            placementId,
            resumeUrl: resumeUrl || "",
            appliedAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "applied",
          });

          // Mirror to old structure for backward compatibility
          transaction.set(
              admin.firestore()
                  .collection("placements")
                  .doc(placementId)
                  .collection("applications")
                  .doc(uid),
              {
                userId: uid,
                placementId,
                resume: resumeUrl || "",
                appliedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "pending",
              }
          );

          isNewApplication = true;
        });

        // Log analytics event (even for duplicate attempts)
        await logAnalyticsEvent({
          eventType: "placement_applied",
          userId: uid,
          metadata: {
            placementId,
            company: company || "Unknown",
            isNewApplication,
          },
        });

        // Return success
        return {
          success: true,
          message: isNewApplication 
              ? "Application submitted successfully" 
              : "Already applied to this placement",
          applicationId,
          isNewApplication,
        };
      } catch (error) {
        console.error("Error in logPlacementApplication:", error);
        
        // If already an HttpsError, rethrow
        if (error instanceof admin.functions.https.HttpsError) {
          throw error;
        }
        
        // Generic error
        throw new admin.functions.https.HttpsError(
            "internal",
            `Failed to submit application: ${error.message}`
        );
      }
    }
);

// ===============================================
// VERSION 6.7: RESUME REVIEW CLOUD FUNCTION
// ===============================================

const RESUME_MONTHLY_LIMIT = 5; // Free reviews per month
const RESUME_MAX_LENGTH = 5000; // Maximum resume characters
const RESUME_MIN_LENGTH = 100; // Minimum resume characters

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
exports.reviewResume = onRequest(
    {cors: true, maxInstances: 5, timeoutSeconds: 120},
    async (request, response) => {
      // Handle usage check (GET request)
      if (request.method === "GET") {
        const userId = request.query.userId;
        const checkUsage = request.query.checkUsage;
        
        if (userId && checkUsage === "true") {
          const usage = await getResumeUsage(userId);
          return response.status(200).json({ usage });
        }
        
        return response.status(400).json({
          error: "Invalid request. Use POST to submit resume.",
        });
      }

      // Validate request method
      if (request.method !== "POST") {
        return response.status(405).json({
          error: "Method not allowed. Use POST.",
        });
      }

      try {
        // Extract data from request
        const { userId, resumeText, targetRole, experienceLevel } = request.body;

        // Validate required fields
        if (!userId) {
          return response.status(401).json({
            error: "Authentication required. Please log in.",
          });
        }

        if (!resumeText) {
          return response.status(400).json({
            error: "Resume text is required.",
          });
        }

        const trimmedResume = resumeText.trim();

        // Validate resume length
        if (trimmedResume.length < RESUME_MIN_LENGTH) {
          return response.status(400).json({
            error: `Resume too short. Minimum ${RESUME_MIN_LENGTH} characters required.`,
          });
        }

        if (trimmedResume.length > RESUME_MAX_LENGTH) {
          return response.status(400).json({
            error: `Resume too long. Maximum ${RESUME_MAX_LENGTH} characters allowed.`,
          });
        }

        console.log(`Resume review request from user: ${userId}`);
        console.log(`Resume length: ${trimmedResume.length} characters`);
        console.log(`Target role: ${targetRole || "General"}`);

        // Check monthly usage limit BEFORE incrementing
        const currentUsage = await getResumeUsage(userId);
        
        if (currentUsage.monthlyCount >= RESUME_MONTHLY_LIMIT) {
          return response.status(429).json({
            error: `Monthly review limit reached (${RESUME_MONTHLY_LIMIT} reviews/month). Resets next month.`,
            usage: currentUsage,
          });
        }

        // Increment usage count (only after quota check passes)
        const usageData = await trackResumeUsage(userId);

        // Generate AI review (Real AI via Groq/HuggingFace)
        let reviewResult;
        try {
          const aiResult = await generateResumeReviewAI(
              trimmedResume,
              targetRole || "General / Entry Level",
              experienceLevel || "Student / Fresher"
          );
          reviewResult = aiResult.review;
          console.log(`Resume review from provider: ${aiResult.providerUsed}`);
        } catch (aiError) {
          console.error("AI provider error in reviewResume:", aiError);
          return response.status(500).json({
            error: "AI analysis failed. Please try again later.",
          });
        }

        // Log analytics event
        await logAnalyticsEvent({
          eventType: "resume_review_completed",
          userId: userId,
          metadata: {
            resumeLength: trimmedResume.length,
            targetRole: targetRole || "General",
            atsScore: reviewResult.atsScore,
            monthlyUsage: usageData.monthlyCount,
          },
        });

        // Return successful response
        return response.status(200).json({
          review: reviewResult,
          usage: usageData,
        });

      } catch (error) {
        console.error("Error in reviewResume function:", error);
        return response.status(500).json({
          error: "Failed to analyze resume. Please try again later.",
        });
      }
    }
);

/**
 * Track resume review usage per user (monthly limit)
 * 
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Usage data {monthlyCount, monthlyLimit, lastResetMonth}
 */
async function trackResumeUsage(userId) {
  const usageRef = admin.firestore()
      .collection("resume_usage")
      .doc(userId);

  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageRef);

      if (!usageDoc.exists) {
        // First time user
        const newUsageData = {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastReviewAt: admin.firestore.Timestamp.now(),
          lastResetMonth: currentMonth,
        };
        transaction.set(usageRef, newUsageData);
        return newUsageData;
      }

      const data = usageDoc.data();
      const lastResetMonth = data.lastResetMonth || "";

      // Check if we need to reset the counter (new month)
      if (lastResetMonth !== currentMonth) {
        // Reset counter for new month
        const resetData = {
          monthlyCount: 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastReviewAt: admin.firestore.Timestamp.now(),
          lastResetMonth: currentMonth,
        };
        transaction.update(usageRef, resetData);
        return resetData;
      } else {
        // Increment counter
        const updatedData = {
          monthlyCount: data.monthlyCount + 1,
          monthlyLimit: RESUME_MONTHLY_LIMIT,
          lastReviewAt: admin.firestore.Timestamp.now(),
          lastResetMonth: currentMonth,
        };
        transaction.update(usageRef, updatedData);
        return updatedData;
      }
    });

    return {
      monthlyCount: result.monthlyCount,
      monthlyLimit: result.monthlyLimit,
      lastResetMonth: result.lastResetMonth,
      lastReviewAt: result.lastReviewAt?.toDate?.()?.toISOString() || null,
    };
  } catch (error) {
    console.error("Error tracking resume usage:", error);
    // Return safe defaults if tracking fails
    return {
      monthlyCount: 1,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
      lastResetMonth: currentMonth,
    };
  }
}

/**
 * Get resume usage without incrementing
 * 
 * @param {string} userId - User's Firebase Auth ID
 * @return {object} Usage data
 */
async function getResumeUsage(userId) {
  try {
    const usageDoc = await admin.firestore()
        .collection("resume_usage")
        .doc(userId)
        .get();

    if (!usageDoc.exists) {
      return {
        monthlyCount: 0,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastResetMonth: null,
      };
    }

    const data = usageDoc.data();
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    // Check if month has reset
    if (data.lastResetMonth !== currentMonth) {
      return {
        monthlyCount: 0,
        monthlyLimit: RESUME_MONTHLY_LIMIT,
        lastResetMonth: currentMonth,
      };
    }

    return {
      monthlyCount: data.monthlyCount || 0,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
      lastResetMonth: data.lastResetMonth,
      lastReviewAt: data.lastReviewAt?.toDate?.()?.toISOString() || null,
    };
  } catch (error) {
    console.error("Error getting resume usage:", error);
    return {
      monthlyCount: 0,
      monthlyLimit: RESUME_MONTHLY_LIMIT,
    };
  }
}

// ===============================================
// VERSION 6.95: AI DEEP ANALYSIS (CALLABLE)
// ===============================================

const AI_MONTHLY_LIMIT = 3; // AI deep analysis calls per month
const AI_MAX_RESUME_LENGTH = 5000; // Max resume chars for AI input

/**
 * generateResumeAnalysis - Firebase Callable Function (v6.95)
 *
 * Sends resume text to a real AI provider (Groq/HuggingFace) for
 * deep analysis including strengths, weaknesses, skill gaps,
 * career suggestions, and improvement roadmap.
 *
 * Flow:
 * 1. Validate auth
 * 2. Check AI usage limit (3/month)
 * 3. Check if analysis already exists for this review
 * 4. Call selected AI provider via abstraction layer
 * 5. Normalize response into structured JSON
 * 6. Save to Firestore (resumeReviews/{id}.aiAnalysis)
 * 7. Update user AI usage counter
 * 8. Return structured result
 *
 * Security:
 * - Auth required (uid from Firebase Auth context)
 * - API keys stored server-side only (env vars)
 * - Resume input sanitized and length-limited
 * - Usage limiting prevents abuse
 */
exports.generateResumeAnalysis = onCall(
    {
      cors: true,
      maxInstances: 5,
      timeoutSeconds: 120,
      // Memory: 256MB is sufficient for API relay
      memory: "256MiB",
    },
    async (request) => {
      // === 1. Validate Authentication ===
      const uid = request.auth?.uid;

      if (!uid) {
        throw new (require("firebase-functions/v2/https").HttpsError)(
            "unauthenticated",
            "You must be logged in to use AI analysis."
        );
      }

      const { reviewId, resumeText, targetRole } = request.data;

      // Validate required fields
      if (!reviewId || typeof reviewId !== "string") {
        throw new (require("firebase-functions/v2/https").HttpsError)(
            "invalid-argument",
            "Missing or invalid reviewId."
        );
      }

      if (!resumeText || typeof resumeText !== "string") {
        throw new (require("firebase-functions/v2/https").HttpsError)(
            "invalid-argument",
            "Resume text is required."
        );
      }

      // Sanitize resume input
      const sanitizedResume = resumeText.trim().substring(0, AI_MAX_RESUME_LENGTH);

      if (sanitizedResume.length < 100) {
        throw new (require("firebase-functions/v2/https").HttpsError)(
            "invalid-argument",
            "Resume text is too short for meaningful analysis (min 100 chars)."
        );
      }

      const safeTargetRole = (targetRole || "General / Entry Level")
          .substring(0, 100)
          .trim();

      console.log(`generateResumeAnalysis: uid=${uid}, reviewId=${reviewId}, ` +
          `resumeLength=${sanitizedResume.length}, role="${safeTargetRole}"`);

      try {
        // === 2. Check if AI analysis already exists ===
        const reviewRef = admin.firestore()
            .collection("users")
            .doc(uid)
            .collection("resumeReviews")
            .doc(reviewId);

        const reviewDoc = await reviewRef.get();

        if (!reviewDoc.exists) {
          throw new (require("firebase-functions/v2/https").HttpsError)(
              "not-found",
              "Resume review not found. Please submit a review first."
          );
        }

        const reviewData = reviewDoc.data();

        // If AI analysis already exists, return cached result
        if (reviewData.aiAnalysis) {
          console.log(`generateResumeAnalysis: Returning cached analysis for ${reviewId}`);
          return {
            success: true,
            cached: true,
            analysis: reviewData.aiAnalysis,
            providerUsed: reviewData.aiProviderUsed || "unknown",
            generatedAt: reviewData.aiGeneratedAt?.toDate?.()?.toISOString() || null,
          };
        }

        // === 3. Check AI usage limit ===
        const userRef = admin.firestore().collection("users").doc(uid);
        const userDoc = await userRef.get();
        const userData = userDoc.exists ? userDoc.data() : {};

        const now = new Date();
        const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

        let aiUsageCount = userData.aiUsageCount || 0;
        const aiUsageResetDate = userData.aiUsageResetDate || "";

        // Reset counter if new month
        if (aiUsageResetDate !== currentMonth) {
          aiUsageCount = 0;
        }

        if (aiUsageCount >= AI_MONTHLY_LIMIT) {
          throw new (require("firebase-functions/v2/https").HttpsError)(
              "resource-exhausted",
              `AI analysis limit reached (${AI_MONTHLY_LIMIT} per month). Resets next month.`
          );
        }

        // === 4. Call AI Provider ===
        console.log(`generateResumeAnalysis: Calling AI provider...`);
        const aiResult = await generateAIResponse(sanitizedResume, safeTargetRole);
        console.log(`generateResumeAnalysis: AI response received from "${aiResult.providerUsed}"`);

        // === 5. Save to Firestore ===
        const aiAnalysis = {
          summary: aiResult.summary,
          strengths: aiResult.strengths,
          weaknesses: aiResult.weaknesses,
          missingSkills: aiResult.missingSkills,
          careerSuggestions: aiResult.careerSuggestions,
          improvementRoadmap: aiResult.improvementRoadmap,
        };

        const aiGeneratedAt = admin.firestore.Timestamp.now();

        // Update the resume review document with AI analysis
        await reviewRef.update({
          aiAnalysis: aiAnalysis,
          aiGeneratedAt: aiGeneratedAt,
          aiProviderUsed: aiResult.providerUsed,
        });

        // === 6. Update user AI usage counter ===
        await userRef.set(
            {
              aiUsageCount: aiUsageCount + 1,
              aiUsageResetDate: currentMonth,
            },
            { merge: true }
        );

        // === 7. Log analytics ===
        await logAnalyticsEvent({
          eventType: "ai_resume_analysis_generated",
          userId: uid,
          metadata: {
            reviewId: reviewId,
            provider: aiResult.providerUsed,
            resumeLength: sanitizedResume.length,
            targetRole: safeTargetRole,
            monthlyUsage: aiUsageCount + 1,
          },
        });

        console.log(`generateResumeAnalysis: Success. Provider: ${aiResult.providerUsed}, ` +
            `Usage: ${aiUsageCount + 1}/${AI_MONTHLY_LIMIT}`);

        // === 8. Return result ===
        return {
          success: true,
          cached: false,
          analysis: aiAnalysis,
          providerUsed: aiResult.providerUsed,
          generatedAt: aiGeneratedAt.toDate().toISOString(),
          usage: {
            aiUsageCount: aiUsageCount + 1,
            aiMonthlyLimit: AI_MONTHLY_LIMIT,
            aiUsageResetDate: currentMonth,
          },
        };
      } catch (error) {
        // Re-throw HttpsError as-is
        if (error.code && error.httpErrorCode) {
          throw error;
        }

        console.error("generateResumeAnalysis error:", error);
        throw new (require("firebase-functions/v2/https").HttpsError)(
            "internal",
            `AI analysis failed: ${error.message || "Unknown error"}`
        );
      }
    }
);

// ===============================================
// VERSION 7.4: AI ECOSYSTEM AUTOMATION LAYER
// ===============================================

const INACTIVITY_REMINDER_HOURS = 48;

exports.onProfileUpdatedRefreshAI = onDocumentWritten(
    {
      document: "users/{userId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const userId = event.params.userId;
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;

      if (!after) return;
      if (after.role !== "student" || after.profileCompleted !== true) return;

      const changed =
        !before ||
        JSON.stringify(before.skills || []) !== JSON.stringify(after.skills || []) ||
        before.careerInterest !== after.careerInterest ||
        before.department !== after.department ||
        before.graduationYear !== after.graduationYear ||
        before.updatedAt !== after.updatedAt;

      if (!changed) return;

      try {
        await refreshRecommendationsForStudent(userId, after);
        await logUserActivity(userId, "profileUpdated", 3, {source: "profile_trigger"});
        await recomputeEngagementSummary(userId, after);
      } catch (error) {
        console.error("onProfileUpdatedRefreshAI error:", error);
      }
    }
);

exports.onResumeReviewCreatedRefreshMatches = onDocumentCreated(
    {
      document: "users/{userId}/resumeReviews/{reviewId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const userId = event.params.userId;
      const resumeData = event.data.data();

      try {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) return;
        const userData = userDoc.data();
        if (userData.role !== "student") return;

        await refreshRecommendationsForStudent(userId, userData, {resumeData});
        await logUserActivity(userId, "resumeReviewed", 5, {
          reviewId: event.params.reviewId,
          atsScore: resumeData.atsScore || 0,
        });
        await recomputeEngagementSummary(userId, userData);
      } catch (error) {
        console.error("onResumeReviewCreatedRefreshMatches error:", error);
      }
    }
);

exports.onOpportunityPostedNotifyStudents = onDocumentCreated(
    {
      document: "opportunities/{opportunityId}",
      region: "us-central1",
      maxInstances: 10,
    },
    async (event) => {
      const opportunityId = event.params.opportunityId;
      const opportunity = event.data.data();

      try {
        const studentsSnapshot = await admin.firestore()
            .collection("users")
            .where("role", "==", "student")
            .where("profileCompleted", "==", true)
            .get();

        if (studentsSnapshot.empty) return;

        const now = admin.firestore.Timestamp.now();
        let batch = admin.firestore().batch();
        let writes = 0;

        for (const student of studentsSnapshot.docs) {
          const notificationRef = admin.firestore()
              .collection("users")
              .doc(student.id)
              .collection("notifications")
              .doc();

          batch.set(notificationRef, {
            type: "newJobPost",
            title: "New Job Opportunity",
            body: `${opportunity.title || "Role"} at ${opportunity.company || "Company"}`,
            data: {opportunityId},
            isRead: false,
            priority: "medium",
            createdAt: now,
          });

          writes++;
          if (writes >= 400) {
            await batch.commit();
            batch = admin.firestore().batch();
            writes = 0;
          }
        }

        if (writes > 0) {
          await batch.commit();
        }
      } catch (error) {
        console.error("onOpportunityPostedNotifyStudents error:", error);
      }
    }
);

exports.autoExpireOpportunities = onSchedule(
    {
      schedule: "every 60 minutes",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        const now = admin.firestore.Timestamp.now();
        const snapshot = await admin.firestore()
            .collection("opportunities")
            .where("isActive", "==", true)
            .where("applicationDeadline", "<=", now)
            .get();

        if (snapshot.empty) return;

        const batch = admin.firestore().batch();
        for (const doc of snapshot.docs) {
          batch.update(doc.ref, {
            isActive: false,
            expiredAt: now,
            updatedAt: now,
          });
        }
        await batch.commit();
      } catch (error) {
        console.error("autoExpireOpportunities error:", error);
      }
    }
);

exports.sendInactivityReminders = onSchedule(
    {
      schedule: "every day 09:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        const now = Date.now();
        const inactivityCutoff = admin.firestore.Timestamp.fromMillis(
            now - INACTIVITY_REMINDER_HOURS * 60 * 60 * 1000
        );

        // 1) Inactive chats with unread messages
        const chatsSnapshot = await admin.firestore()
            .collection("chats")
            .where("lastMessageAt", "<", inactivityCutoff)
            .get();

        for (const chatDoc of chatsSnapshot.docs) {
          const chat = chatDoc.data();
          const unreadCount = chat.unreadCount || {};
          const participantIds = chat.participantIds || [];

          for (const participantId of participantIds) {
            if ((unreadCount[participantId] || 0) <= 0) continue;

            await maybeCreateNotification(participantId, "inactiveChatReminder", {
              title: "Chat Reminder",
              body: "You have unread chat messages waiting for your reply.",
              data: {chatId: chatDoc.id},
              priority: "low",
            });
          }
        }

        // 2) Pending mentorship requests older than 3 days
        const mentorshipCutoff = admin.firestore.Timestamp.fromMillis(
            now - 3 * 24 * 60 * 60 * 1000
        );
        const pendingMentorships = await admin.firestore()
            .collection("mentorship_requests")
            .where("status", "==", "pending")
            .where("createdAt", "<=", mentorshipCutoff)
            .get();

        for (const requestDoc of pendingMentorships.docs) {
          const request = requestDoc.data();
          if (request.alumniId) {
            await maybeCreateNotification(request.alumniId, "reminder", {
              title: "Mentorship Request Pending",
              body: `You have a pending request from ${request.studentName || "a student"}.`,
              data: {requestId: requestDoc.id},
              priority: "medium",
            });
          }
          if (request.studentId) {
            await maybeCreateNotification(request.studentId, "reminder", {
              title: "Mentorship Follow-up",
              body: "Your mentorship request is still pending. Try sending a concise follow-up.",
              data: {requestId: requestDoc.id},
              priority: "low",
            });
          }
        }
      } catch (error) {
        console.error("sendInactivityReminders error:", error);
      }
    }
);

exports.recomputeEngagementScores = onSchedule(
    {
      schedule: "every day 01:00",
      region: "us-central1",
      timeZone: "UTC",
    },
    async () => {
      try {
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .where("profileCompleted", "==", true)
            .get();

        for (const userDoc of usersSnapshot.docs) {
          await recomputeEngagementSummary(userDoc.id, userDoc.data());
        }
      } catch (error) {
        console.error("recomputeEngagementScores error:", error);
      }
    }
);

async function refreshRecommendationsForStudent(userId, userData, options = {}) {
  const studentSkills = normalizeTokens(userData.skills || []);
  const careerSignals = normalizeTokens([
    ...(userData.career?.interests || []),
    ...(userData.career?.preferredRoles || []),
    userData.careerInterest || "",
  ]);
  const resumeMissing = normalizeTokens(options.resumeData?.missingKeywords || []);

  const [alumniSnapshot, opportunitiesSnapshot] = await Promise.all([
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
  ]);

  const mentorRecommendations = [];
  for (const alumniDoc of alumniSnapshot.docs) {
    if (alumniDoc.id === userId) continue;
    const alumni = alumniDoc.data();
    const mentorSkills = normalizeTokens(alumni.skills || []);
    const overlapSkills = intersectionCount(studentSkills, mentorSkills);

    let score = overlapSkills * 18;
    if (careerSignals.has((alumni.jobRole || "").toLowerCase())) score += 15;
    if (careerSignals.has((alumni.company || "").toLowerCase())) score += 10;
    if (userData.department && alumni.department && userData.department === alumni.department) {
      score += 10;
    }
    if (resumeMissing.size > 0) {
      const bridging = intersectionCount(resumeMissing, mentorSkills);
      score += Math.min(12, bridging * 4);
    }
    score = Math.min(100, score);
    if (score < 45) continue;

    mentorRecommendations.push({
      id: `mentor_${alumniDoc.id}`,
      userId,
      type: "mentor",
      priority: score >= 75 ? "high" : "medium",
      title: `Connect with ${alumni.personal?.displayName || alumni.personal?.fullName || "Mentor"}`,
      description: `${alumni.jobRole || "Alumni mentor"} at ${alumni.company || "CampusConnect Network"}`,
      score,
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
      metadata: {
        alumniId: alumniDoc.id,
        company: alumni.company || null,
        jobRole: alumni.jobRole || null,
      },
    });
  }
  mentorRecommendations.sort((a, b) => b.score - a.score);

  const jobRecommendations = [];
  for (const opportunityDoc of opportunitiesSnapshot.docs) {
    const opportunity = opportunityDoc.data();
    const opportunitySkills = normalizeTokens(opportunity.skills || []);
    let score = intersectionCount(studentSkills, opportunitySkills) * 20;

    const titleTokens = normalizeTokens([opportunity.title || "", opportunity.company || ""]);
    score += intersectionCount(careerSignals, titleTokens) * 12;

    const missingForRole = intersectionCount(resumeMissing, opportunitySkills);
    score += Math.max(0, 10 - missingForRole * 2);
    score = Math.min(100, score);

    if (score < 40) continue;

    jobRecommendations.push({
      id: `job_${opportunityDoc.id}`,
      userId,
      type: "job",
      priority: score >= 70 ? "high" : "medium",
      title: `${opportunity.title || "Opportunity"} at ${opportunity.company || "Company"}`,
      description: `AI match score: ${score}%`,
      score,
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 3 * 24 * 60 * 60 * 1000),
      metadata: {
        opportunityId: opportunityDoc.id,
      },
    });
  }
  jobRecommendations.sort((a, b) => b.score - a.score);

  const recommendations = [
    ...mentorRecommendations.slice(0, 4),
    ...jobRecommendations.slice(0, 4),
    {
      id: "nudge_ai_chat",
      userId,
      type: "chat",
      priority: "medium",
      title: "Use AI Career Assistant",
      description: "Get interview Q&A simulation, skill-gap analysis, and resume guidance.",
      score: 65,
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 2 * 24 * 60 * 60 * 1000),
      metadata: {action: "open_ai_chat"},
    },
  ];

  const existingSnapshot = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("recommendations")
      .where("isActive", "==", true)
      .get();

  const batch = admin.firestore().batch();
  for (const oldDoc of existingSnapshot.docs) {
    batch.update(oldDoc.ref, {isActive: false});
  }
  for (const recommendation of recommendations) {
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
    total: recommendations.length,
  }, {merge: true});

  await batch.commit();

  if (mentorRecommendations.length > 0) {
    await maybeCreateNotification(userId, "mentorMatch", {
      title: "New Mentor Match",
      body: `${mentorRecommendations[0].title} (${mentorRecommendations[0].score}% match)`,
      data: {
        alumniId: mentorRecommendations[0].metadata.alumniId,
        matchScore: mentorRecommendations[0].score,
      },
      priority: "high",
    });
  }
  if (jobRecommendations.length > 0) {
    await maybeCreateNotification(userId, "jobMatch", {
      title: "New Job Match",
      body: `${jobRecommendations[0].title} (${jobRecommendations[0].score}% match)`,
      data: {
        opportunityId: jobRecommendations[0].metadata.opportunityId,
        matchScore: jobRecommendations[0].score,
      },
      priority: "high",
    });
  }
}

async function maybeCreateNotification(userId, type, payload) {
  const recentCutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 20 * 60 * 60 * 1000
  );

  const recent = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .where("type", "==", type)
      .where("createdAt", ">=", recentCutoff)
      .limit(1)
      .get();

  if (!recent.empty) return;

  await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type,
        title: payload.title || "Notification",
        body: payload.body || "",
        data: payload.data || {},
        isRead: false,
        priority: payload.priority || "low",
        createdAt: admin.firestore.Timestamp.now(),
      });
}

async function logUserActivity(userId, eventType, points, metadata = {}) {
  await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("activities")
      .add({
        userId,
        eventType,
        points,
        metadata,
        occurredAt: admin.firestore.Timestamp.now(),
      });
}

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

  const badges = [
    buildBadge("profile_pro", "profilePro", "Profile Pro", "Complete profile for stronger matches", profileStrength, 100),
    buildBadge("consistency_champion", "consistencyChampion", "Consistency Champion", "Stay active 7 days in a row", dailyStreak, 7),
    buildBadge("active_student", "activeStudent", "Active Student", "Earn 50 engagement points", activityPoints, 50),
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

function normalizeTokens(values) {
  return new Set(
      (values || [])
          .flatMap((value) => String(value || "").split(/[,\s/]+/g))
          .map((token) => token.trim().toLowerCase())
          .filter((token) => token.length > 1)
  );
}

function intersectionCount(setA, setB) {
  let count = 0;
  for (const value of setA) {
    if (setB.has(value)) count++;
  }
  return count;
}
