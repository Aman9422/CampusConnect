const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * AI Assistant Cloud Function
 * 
 * This function acts as a gateway between the Flutter app and AI services.
 * It receives user messages and returns AI-generated responses.
 * 
 * For Version 3, this uses a mock AI response for demonstration.
 * In production, replace with actual AI API (OpenAI, Google AI, etc.)
 * 
 * @param {object} request - Contains userId and message
 * @param {object} response - Returns AI response
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
        if (trimmedMessage.length === 0) {
          return response.status(400).json({
            error: "Message cannot be empty",
          });
        }

        if (trimmedMessage.length > 1000) {
          return response.status(400).json({
            error: "Message too long. Maximum 1000 characters.",
          });
        }

        // Log the interaction (for analytics/debugging)
        console.log(`AI Request from user: ${userId}`);
        console.log(`Message: ${trimmedMessage.substring(0, 50)}...`);

        // Store message in Firestore for history
        await admin.firestore()
            .collection("ai_conversations")
            .add({
              userId: userId,
              message: trimmedMessage,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              status: "processed",
            });

        // ===============================================
        // AI RESPONSE LOGIC
        // ===============================================
        // For Version 3, we use intelligent mock responses
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

        // Return successful response
        return response.status(200).json({
          response: aiResponse,
          timestamp: new Date().toISOString(),
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
