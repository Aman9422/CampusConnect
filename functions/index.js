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

        // Generate AI review (mock implementation - replace with actual AI API)
        const reviewResult = await generateResumeReview(
            trimmedResume,
            targetRole || "General / Entry Level",
            experienceLevel || "Student / Fresher"
        );

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

/**
 * Generate AI resume review (mock implementation)
 * 
 * This function analyzes the resume and provides structured feedback.
 * In production, replace with actual AI API call (OpenAI, Google AI, etc.)
 * 
 * @param {string} resumeText - The resume content
 * @param {string} targetRole - Target job role
 * @param {string} experienceLevel - Experience level
 * @return {object} Resume review analysis
 */
async function generateResumeReview(resumeText, targetRole, experienceLevel) {
  const lowerResume = resumeText.toLowerCase();
  
  // === ATS SCORE CALCULATION ===
  let atsScore = 50; // Base score
  
  // Check for key sections
  const hasSummary = lowerResume.includes("summary") || lowerResume.includes("objective") || lowerResume.includes("about");
  const hasSkills = lowerResume.includes("skills") || lowerResume.includes("technologies");
  const hasExperience = lowerResume.includes("experience") || lowerResume.includes("work history");
  const hasEducation = lowerResume.includes("education") || lowerResume.includes("academic");
  const hasProjects = lowerResume.includes("projects") || lowerResume.includes("portfolio");
  
  if (hasSummary) atsScore += 8;
  if (hasSkills) atsScore += 10;
  if (hasExperience) atsScore += 8;
  if (hasEducation) atsScore += 8;
  if (hasProjects) atsScore += 6;
  
  // Check for action verbs
  const actionVerbs = ["developed", "created", "implemented", "designed", "managed", "led", "built", "improved", "achieved", "increased", "reduced", "optimized"];
  const actionVerbCount = actionVerbs.filter(v => lowerResume.includes(v)).length;
  atsScore += Math.min(actionVerbCount * 2, 10);
  
  // Check for quantifiable results
  const hasNumbers = /\d+%|\d+\+|\$\d+|\d+ (users|projects|clients|team)/i.test(resumeText);
  if (hasNumbers) atsScore += 8;
  
  // Penalize issues
  if (resumeText.length < 500) atsScore -= 10; // Too short
  if (lowerResume.includes("responsibilities include")) atsScore -= 5; // Weak phrasing
  if (!/@/.test(resumeText)) atsScore -= 3; // No email
  
  // Cap score
  atsScore = Math.max(20, Math.min(95, atsScore));
  
  // === IDENTIFY STRENGTHS ===
  const strengths = [];
  if (hasSummary) strengths.push("Clear professional summary present");
  if (hasSkills) strengths.push("Dedicated skills section included");
  if (hasProjects) strengths.push("Projects section demonstrates practical experience");
  if (actionVerbCount >= 3) strengths.push("Good use of action verbs");
  if (hasNumbers) strengths.push("Includes quantifiable achievements");
  if (hasEducation) strengths.push("Education details properly listed");
  if (strengths.length === 0) strengths.push("Resume is structured and readable");
  
  // === MISSING KEYWORDS ===
  const commonKeywords = [
    "problem-solving", "communication", "teamwork", "leadership",
    "analytical", "detail-oriented", "time management", "adaptable",
  ];
  const techKeywords = [
    "git", "agile", "api", "database", "testing", "debugging",
    "cloud", "deployment", "documentation",
  ];
  
  const missingKeywords = [];
  
  // Check common keywords
  commonKeywords.forEach(kw => {
    if (!lowerResume.includes(kw.toLowerCase())) {
      if (missingKeywords.length < 5) {
        missingKeywords.push(kw);
      }
    }
  });
  
  // Check tech keywords for tech roles
  if (targetRole.toLowerCase().includes("software") || 
      targetRole.toLowerCase().includes("developer") ||
      targetRole.toLowerCase().includes("engineer")) {
    techKeywords.forEach(kw => {
      if (!lowerResume.includes(kw.toLowerCase())) {
        if (missingKeywords.length < 8) {
          missingKeywords.push(kw);
        }
      }
    });
  }
  
  // === FORMAT ISSUES ===
  const formatIssues = [];
  if (!hasSummary) formatIssues.push("Consider adding a professional summary or objective statement");
  if (!hasSkills) formatIssues.push("Add a dedicated skills section for ATS scanning");
  if (resumeText.length < 500) formatIssues.push("Resume appears too brief - consider adding more detail");
  if (resumeText.length > 4000) formatIssues.push("Resume may be too long - consider condensing to 1-2 pages");
  if (lowerResume.includes("responsibilities include")) formatIssues.push("Replace 'Responsibilities include' with action verbs");
  if (!/@/.test(resumeText)) formatIssues.push("Ensure contact email is included");
  if (!/\d{10}|\d{3}[-.\s]\d{3}[-.\s]\d{4}/.test(resumeText)) formatIssues.push("Consider adding a phone number for contact");
  
  // === BULLET IMPROVEMENTS ===
  const bulletImprovements = [];
  
  // Find weak bullet patterns and suggest improvements
  const weakPatterns = [
    {
      pattern: /responsible for/gi,
      original: "Responsible for managing team tasks",
      improved: "Led a team of 5 members, coordinating daily tasks and improving delivery time by 20%",
      reason: "Use action verbs and quantify impact instead of passive phrasing",
    },
    {
      pattern: /helped with/gi,
      original: "Helped with project development",
      improved: "Contributed to the development of 3 key features, reducing user onboarding time",
      reason: "Be specific about your contribution and its impact",
    },
    {
      pattern: /worked on/gi,
      original: "Worked on various coding projects",
      improved: "Developed and deployed 5+ full-stack applications using React and Node.js",
      reason: "Specify technologies used and quantify your work",
    },
  ];
  
  weakPatterns.forEach(wp => {
    if (wp.pattern.test(resumeText)) {
      bulletImprovements.push({
        original: wp.original,
        improved: wp.improved,
        reason: wp.reason,
      });
    }
  });
  
  // Add generic improvement if resume lacks metrics
  if (!hasNumbers && bulletImprovements.length < 3) {
    bulletImprovements.push({
      original: "Developed web applications for clients",
      improved: "Developed 3 web applications serving 500+ users, achieving 99.9% uptime",
      reason: "Add specific numbers and metrics to demonstrate impact",
    });
  }
  
  // === SECTION ADVICE ===
  const sectionAdvice = {
    summary: hasSummary 
        ? "Good summary present. Consider tailoring it for each application."
        : "Add a 2-3 line professional summary highlighting your key strengths and career goals.",
    skills: hasSkills
        ? "Skills section present. Organize by category (Languages, Frameworks, Tools) for better readability."
        : "Add a dedicated skills section. List technical and soft skills relevant to your target role.",
    projects: hasProjects
        ? "Projects section adds value. Include links to live demos or GitHub repositories."
        : "Add 2-3 relevant projects with brief descriptions, technologies used, and your role.",
    experience: hasExperience
        ? "Experience section found. Focus on achievements over responsibilities."
        : "Include internships, freelance work, or relevant volunteer experience.",
    education: hasEducation
        ? "Education properly listed. Include relevant coursework or certifications."
        : "Add your educational background with degree, institution, and graduation year.",
  };
  
  // === OVERALL ADVICE ===
  let overallAdvice = "";
  if (atsScore >= 80) {
    overallAdvice = "Your resume is well-optimized for ATS. Focus on tailoring it for specific job descriptions by including keywords from the job posting. Consider having someone review it for any typos or grammatical errors.";
  } else if (atsScore >= 60) {
    overallAdvice = "Your resume has a good foundation but needs some improvements. Focus on adding more quantifiable achievements and ensuring all key sections are present. Use strong action verbs to start each bullet point.";
  } else if (atsScore >= 40) {
    overallAdvice = "Your resume needs significant improvements for ATS compatibility. Add missing sections (summary, skills), include more specific achievements with numbers, and ensure proper formatting. Review the section advice above.";
  } else {
    overallAdvice = "Your resume requires substantial revision. Start by adding all essential sections: Summary, Skills, Experience, Education, and Projects. Focus on quantifiable achievements and use industry-relevant keywords.";
  }
  
  // === HIREABILITY VERDICT ===
  let hireabilityVerdict = "";
  if (atsScore >= 80) {
    hireabilityVerdict = "Strong candidate - This resume is likely to pass ATS screening and make a positive impression.";
  } else if (atsScore >= 60) {
    hireabilityVerdict = "Competitive candidate - With minor improvements, this resume will stand out to recruiters.";
  } else if (atsScore >= 40) {
    hireabilityVerdict = "Average candidate - Resume may pass some ATS systems but needs work to be competitive.";
  } else {
    hireabilityVerdict = "Needs improvement - This resume may struggle with ATS screening. Follow the suggestions above.";
  }
  
  return {
    atsScore,
    strengths,
    missingKeywords,
    formatIssues,
    bulletImprovements,
    sectionAdvice,
    overallAdvice,
    hireabilityVerdict,
  };
}
