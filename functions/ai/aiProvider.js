/**
 * CampusConnect v7.0 - AI Provider Abstraction Layer
 *
 * Provides a unified interface for AI providers (Groq, HuggingFace).
 * The active provider is determined by the AI_PROVIDER environment variable.
 *
 * Exported functions:
 *   generateAIResponse(resumeText, targetRole) - Deep analysis (JSON)
 *   generateChatResponse(message) - Chat assistant (plain text)
 *   generateResumeReviewAI(resumeText, targetRole, experienceLevel) - Resume review (JSON)
 *
 * Providers:
 *   groq       - Groq LPU Cloud with LLaMA 3.1 8B Instant (fast, free tier)
 *   huggingface - HuggingFace Inference Providers with LLaMA 3.1 8B Instruct (multi-provider)
 *
 * Environment:
 *   AI_PROVIDER = "groq" | "huggingface" (default: "groq")
 *   GROQ_API_KEY = Groq API key from https://console.groq.com
 *   HUGGINGFACE_API_KEY = HuggingFace token from https://huggingface.co/settings/tokens
 */

const { callGroqAPI } = require("./groqProvider");
const { callHuggingFaceAPI } = require("./huggingfaceProvider");
const { normalizeAIResponse, extractJSON } = require("./normalizeResponse");

// ============================================================
// SYSTEM PROMPTS
// ============================================================

/**
 * Deep Analysis system prompt - strict JSON output.
 * Used by generateResumeAnalysis (v6.95 callable function).
 */
const SYSTEM_PROMPT = `You are an expert resume analyst and career advisor. Analyze the provided resume and return ONLY a valid JSON object with NO additional text, markdown, or explanation.

The JSON must follow this EXACT structure:
{
  "summary": "A 2-3 sentence professional summary of the resume's overall quality and ATS compatibility",
  "strengths": ["strength1", "strength2", "strength3"],
  "weaknesses": ["weakness1", "weakness2", "weakness3"],
  "missingSkills": ["skill1", "skill2", "skill3"],
  "careerSuggestions": ["suggestion1", "suggestion2", "suggestion3"],
  "improvementRoadmap": {
    "30_days": ["action1", "action2", "action3"],
    "60_days": ["action1", "action2", "action3"]
  }
}

Rules:
- Provide actionable, specific feedback (not generic).
- Each array should have 3-5 items.
- Focus on ATS optimization, industry relevance, and career growth.
- Tailor suggestions to the target role if provided.
- Return ONLY the JSON object. No markdown code blocks, no explanation.`;

/**
 * Chat Assistant system prompt - plain text output.
 * Used by askAI (chat feature).
 */
const CHAT_SYSTEM_PROMPT = `You are CampusConnect AI Assistant — a friendly, knowledgeable campus career advisor built into the CampusConnect app. You help college students with:

• Placement and job interview preparation
• Resume building and career guidance
• Study tips and academic advice
• Project ideas and skill development
• Career path exploration

Guidelines:
- Be concise but helpful (aim for 3-8 short paragraphs or bullet points).
- Give actionable, specific advice — not generic motivational fluff.
- Use a warm, encouraging tone with occasional emojis (sparingly).
- If the user greets you, introduce yourself briefly and ask how you can help.
- If you don't know something specific, be honest and suggest where to find the answer.
- Stay focused on education, career, and professional development topics.
- Format responses with line breaks and bullet points for readability.
- Do NOT return JSON. Respond in natural conversational text.`;

/**
 * Resume Review system prompt - strict JSON output.
 * Used by reviewResume (resume review feature).
 */
const RESUME_REVIEW_SYSTEM_PROMPT = `You are an expert ATS (Applicant Tracking System) resume reviewer and hiring consultant. Analyze the provided resume thoroughly and return ONLY a valid JSON object with NO additional text, markdown, or explanation.

The JSON must follow this EXACT structure:
{
  "atsScore": 72,
  "strengths": ["strength1", "strength2", "strength3"],
  "missingKeywords": ["keyword1", "keyword2", "keyword3"],
  "formatIssues": ["issue1", "issue2"],
  "bulletImprovements": [
    {
      "original": "Weak bullet point found in the resume",
      "improved": "Stronger rewritten version with metrics and action verbs",
      "reason": "Brief explanation of why the improvement matters"
    }
  ],
  "sectionAdvice": {
    "summary": "Advice for the summary/objective section",
    "skills": "Advice for the skills section",
    "projects": "Advice for the projects section",
    "experience": "Advice for the experience section",
    "education": "Advice for the education section"
  },
  "overallAdvice": "2-3 sentences of actionable overall advice tailored to this specific resume",
  "hireabilityVerdict": "One sentence: hiring likelihood assessment (e.g., 'Strong candidate - likely to pass ATS screening')"
}

Rules:
- atsScore must be an integer 0-100 based on real ATS criteria (keyword density, formatting, section presence, action verbs, quantified achievements).
- strengths: 3-5 specific things the resume does well.
- missingKeywords: 3-8 keywords/skills missing but important for the target role.
- formatIssues: 1-5 formatting or structural problems found.
- bulletImprovements: 1-3 specific before/after rewrites of weak bullet points from the resume. Use actual text from the resume for "original".
- sectionAdvice: Advice for each of the 5 sections. If a section is missing from the resume, advise adding it.
- Be specific and actionable — reference actual content from the resume.
- Return ONLY the JSON object. No markdown code blocks, no explanation.`;

// ============================================================
// PROMPT BUILDERS
// ============================================================

/**
 * Build user prompt for deep analysis.
 */
function buildUserPrompt(resumeText, targetRole) {
  return `Analyze the following resume for the target role: "${targetRole}".

RESUME:
---
${resumeText}
---

Return ONLY a valid JSON object with: summary, strengths, weaknesses, missingSkills, careerSuggestions, and improvementRoadmap (with 30_days and 60_days arrays).`;
}

/**
 * Build user prompt for resume review.
 */
function buildResumeReviewPrompt(resumeText, targetRole, experienceLevel) {
  return `Review the following resume for ATS compatibility.

TARGET ROLE: ${targetRole}
EXPERIENCE LEVEL: ${experienceLevel}

RESUME:
---
${resumeText}
---

Return ONLY a valid JSON object with: atsScore, strengths, missingKeywords, formatIssues, bulletImprovements, sectionAdvice, overallAdvice, and hireabilityVerdict.`;
}

// ============================================================
// AI CALL ROUTER (shared by all functions)
// ============================================================

/**
 * Route an AI call to the configured provider.
 *
 * @param {string} systemPrompt - System-level instructions
 * @param {string} userPrompt - User message
 * @param {object} [options] - Options passed to the provider
 * @param {boolean} [options.jsonMode] - Whether to request JSON output
 * @returns {Promise<{content: string, provider: string}>}
 */
async function callAIProvider(systemPrompt, userPrompt, options = {}) {
  const provider = (process.env.AI_PROVIDER || "groq").toLowerCase();

  console.log(`AI Provider: Using "${provider}" (jsonMode: ${options.jsonMode !== false})`);

  let rawResponse;

  switch (provider) {
    case "groq":
      rawResponse = await callGroqAPI(systemPrompt, userPrompt, options);
      break;

    case "huggingface":
      rawResponse = await callHuggingFaceAPI(systemPrompt, userPrompt, options);
      break;

    default:
      throw new Error(
        `Unknown AI provider: "${provider}". Supported: groq, huggingface`
      );
  }

  return { content: rawResponse, provider };
}

// ============================================================
// EXPORTED FUNCTIONS
// ============================================================

/**
 * Generate AI-powered deep resume analysis (v6.95).
 * Returns structured JSON with summary, strengths, weaknesses, etc.
 *
 * @param {string} resumeText - Resume content (plain text)
 * @param {string} targetRole - Target job role
 * @returns {Promise<object>} Normalized AI analysis result
 */
async function generateAIResponse(resumeText, targetRole) {
  const userPrompt = buildUserPrompt(resumeText, targetRole);
  const { content, provider } = await callAIProvider(SYSTEM_PROMPT, userPrompt, { jsonMode: true });

  // Normalize the raw response into structured format
  const normalized = normalizeAIResponse(content);

  return {
    ...normalized,
    providerUsed: provider,
  };
}

/**
 * Generate AI chat response for the campus assistant.
 * Returns plain text (not JSON).
 *
 * @param {string} message - User's chat message
 * @returns {Promise<{response: string, providerUsed: string}>}
 */
async function generateChatResponse(message) {
  const { content, provider } = await callAIProvider(
    CHAT_SYSTEM_PROMPT,
    message,
    { jsonMode: false }
  );

  return {
    response: content.trim(),
    providerUsed: provider,
  };
}

/**
 * Generate AI-powered resume review with ATS scoring.
 * Returns structured JSON matching the ResumeReview model.
 *
 * @param {string} resumeText - Resume content (plain text)
 * @param {string} targetRole - Target job role
 * @param {string} experienceLevel - Experience level
 * @returns {Promise<{review: object, providerUsed: string}>}
 */
async function generateResumeReviewAI(resumeText, targetRole, experienceLevel) {
  const userPrompt = buildResumeReviewPrompt(resumeText, targetRole, experienceLevel);
  const { content, provider } = await callAIProvider(
    RESUME_REVIEW_SYSTEM_PROMPT,
    userPrompt,
    { jsonMode: true }
  );

  // Parse and normalize the resume review response
  const review = normalizeResumeReviewResponse(content);

  return {
    review,
    providerUsed: provider,
  };
}

/**
 * Normalize the raw AI response into the resume review structure
 * expected by the Flutter client (ResumeReview model).
 *
 * @param {string} rawResponse - Raw text from the AI provider
 * @returns {object} Normalized resume review object
 */
function normalizeResumeReviewResponse(rawResponse) {
  if (!rawResponse || typeof rawResponse !== "string") {
    throw new Error("Empty or invalid AI response for resume review");
  }

  // Extract JSON from possible markdown/extra text
  const jsonString = extractJSON(rawResponse);

  let parsed;
  try {
    parsed = JSON.parse(jsonString);
  } catch (parseError) {
    // Try fixing trailing commas
    try {
      const fixed = jsonString.replace(/,\s*}/g, "}").replace(/,\s*\]/g, "]");
      parsed = JSON.parse(fixed);
    } catch (_) {
      throw new Error(
        `AI returned invalid resume review JSON: ${parseError.message}`
      );
    }
  }

  // Validate and normalize each field to match Flutter's ResumeReview model
  const atsScore = typeof parsed.atsScore === "number"
    ? Math.max(0, Math.min(100, Math.round(parsed.atsScore)))
    : 50;

  const strengths = ensureStringArray(parsed.strengths, 5);
  const missingKeywords = ensureStringArray(
    parsed.missingKeywords || parsed.missing_keywords, 8
  );
  const formatIssues = ensureStringArray(
    parsed.formatIssues || parsed.format_issues, 5
  );

  // Normalize bullet improvements
  let bulletImprovements = [];
  if (Array.isArray(parsed.bulletImprovements || parsed.bullet_improvements)) {
    const raw = parsed.bulletImprovements || parsed.bullet_improvements;
    bulletImprovements = raw
      .filter((item) => item && typeof item === "object")
      .slice(0, 3)
      .map((item) => ({
        original: String(item.original || "").trim(),
        improved: String(item.improved || "").trim(),
        reason: String(item.reason || "").trim(),
      }));
  }

  // Normalize section advice
  const rawAdvice = parsed.sectionAdvice || parsed.section_advice || {};
  const sectionAdvice = {
    summary: String(rawAdvice.summary || "").trim() || "Consider adding a professional summary.",
    skills: String(rawAdvice.skills || "").trim() || "Add a dedicated skills section.",
    projects: String(rawAdvice.projects || "").trim() || "Include relevant projects with technologies used.",
    experience: String(rawAdvice.experience || "").trim() || "Add experience with quantified achievements.",
    education: String(rawAdvice.education || "").trim() || "Include your educational background.",
  };

  const overallAdvice = typeof parsed.overallAdvice === "string"
    ? parsed.overallAdvice.trim()
    : "Focus on adding quantifiable achievements and tailoring your resume to the target role.";

  const hireabilityVerdict = typeof parsed.hireabilityVerdict === "string"
    ? parsed.hireabilityVerdict.trim()
    : atsScore >= 70
      ? "Competitive candidate - resume is well-structured for ATS screening."
      : "Needs improvement - follow the suggestions above to strengthen your resume.";

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

/**
 * Helper: ensure value is an array of non-empty strings.
 */
function ensureStringArray(value, maxItems) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item) => typeof item === "string" && item.trim().length > 0)
    .map((item) => item.trim())
    .slice(0, maxItems);
}

module.exports = {
  generateAIResponse,
  generateChatResponse,
  generateResumeReviewAI,
  SYSTEM_PROMPT,
  CHAT_SYSTEM_PROMPT,
  RESUME_REVIEW_SYSTEM_PROMPT,
  buildUserPrompt,
};
