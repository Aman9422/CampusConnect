const {onRequest, onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

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
        // AI RESPONSE LOGIC
        // ===============================================
        // For Version 3/4, we use intelligent mock responses
        // Replace this section with actual AI API calls in production
        
        const aiResponse = generateMockAIResponse(trimmedMessage);

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

/**
 * Generate intelligent mock AI response based on message content
 * 
 * This function analyzes the user's message and provides contextual responses.
 * In production, replace this with actual AI API integration.
 * 
 * @param {string} message - User's message
 * @return {string} AI-generated response
 */
function generateMockAIResponse(message) {
  const lowerMessage = message.toLowerCase();

  // Academic help responses
  if (lowerMessage.includes("placement") || 
      lowerMessage.includes("job") || 
      lowerMessage.includes("interview")) {
    return "For placement preparation, focus on:\n\n" +
           "1. Technical Skills: Practice coding on platforms like " +
           "LeetCode and HackerRank\n" +
           "2. Resume: Highlight projects and relevant experience\n" +
           "3. Mock Interviews: Practice with peers or use online platforms\n" +
           "4. Company Research: Understand the company culture and values\n\n" +
           "Check the Placements tab for current opportunities!";
  }

  if (lowerMessage.includes("resume") || lowerMessage.includes("cv")) {
    return "Creating a strong resume:\n\n" +
           "✓ Keep it to 1-2 pages\n" +
           "✓ Use action verbs (developed, implemented, led)\n" +
           "✓ Quantify achievements (increased by 30%, reduced time by 50%)\n" +
           "✓ Include relevant projects and skills\n" +
           "✓ Proofread carefully\n\n" +
           "Would you like specific tips for any section?";
  }

  if (lowerMessage.includes("study") || 
      lowerMessage.includes("exam") || 
      lowerMessage.includes("test")) {
    return "Effective study strategies:\n\n" +
           "1. Create a study schedule and stick to it\n" +
           "2. Use active recall (test yourself frequently)\n" +
           "3. Take regular breaks (Pomodoro technique)\n" +
           "4. Form study groups for difficult topics\n" +
           "5. Review notes within 24 hours of class\n\n" +
           "Check the Notes section for study materials!";
  }

  if (lowerMessage.includes("project") || lowerMessage.includes("idea")) {
    return "Great project ideas for your portfolio:\n\n" +
           "• Web/Mobile App: Task manager, budget tracker, social platform\n" +
           "• Data Science: Predictive models, data visualization dashboards\n" +
           "• DevOps: CI/CD pipeline, containerized applications\n" +
           "• AI/ML: Chatbot, recommendation system, image classifier\n\n" +
           "Choose something you're passionate about!";
  }

  if (lowerMessage.includes("career") || lowerMessage.includes("future")) {
    return "Building a successful career:\n\n" +
           "1. Continuous Learning: Stay updated with industry trends\n" +
           "2. Networking: Connect with professionals on LinkedIn\n" +
           "3. Internships: Gain real-world experience\n" +
           "4. Personal Projects: Build a strong portfolio\n" +
           "5. Soft Skills: Communication and teamwork matter\n\n" +
           "Remember, it's a marathon, not a sprint!";
  }

  if (lowerMessage.includes("skill") || lowerMessage.includes("learn")) {
    return "Top skills to develop:\n\n" +
           "Technical:\n" +
           "• Programming (Python, Java, JavaScript)\n" +
           "• Data Structures & Algorithms\n" +
           "• Web Development (React, Node.js)\n" +
           "• Cloud platforms (AWS, Azure, GCP)\n\n" +
           "Soft Skills:\n" +
           "• Problem-solving\n" +
           "• Communication\n" +
           "• Time management\n" +
           "• Teamwork\n\n" +
           "Which area interests you most?";
  }

  if (lowerMessage.includes("hello") || 
      lowerMessage.includes("hi") || 
      lowerMessage.includes("hey")) {
    return "Hello! I'm your CampusConnect AI Assistant. 👋\n\n" +
           "I can help you with:\n" +
           "• Placement and interview preparation\n" +
           "• Resume and career guidance\n" +
           "• Study tips and academic advice\n" +
           "• Project ideas and skill development\n\n" +
           "What would you like to know today?";
  }

  if (lowerMessage.includes("thank")) {
    return "You're welcome! I'm always here to help. " +
           "Feel free to ask me anything about academics, " +
           "placements, or career guidance. Good luck! 🌟";
  }

  // Default helpful response
  return "I understand you're asking about: \"" + message + "\"\n\n" +
         "I'm here to help with:\n" +
         "• Academic guidance and study tips\n" +
         "• Placement and interview preparation\n" +
         "• Resume building and career advice\n" +
         "• Project ideas and skill development\n\n" +
         "Could you provide more details about what you'd like to know? " +
         "I'll do my best to assist you!";
}

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
