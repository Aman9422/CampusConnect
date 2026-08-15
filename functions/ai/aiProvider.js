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
 *   groq       - Groq LPU Cloud with openai/gpt-oss-20b (v8.8 primary)
 *   huggingface - HuggingFace Inference Providers with openai/gpt-oss-20b (v8.8 fallback)
 *
 * Fallback (v8.8): when the configured primary provider fails/times out, the
 * request automatically retries against HuggingFace Inference Providers so
 * chat, resume review and deep analysis all stay available. No duplicate
 * pipeline — one router, one normalized response.
 *
 * Environment:
 *   AI_PROVIDER = "groq" | "huggingface" (default: "groq")
 *   GROQ_API_KEY = Groq API key from https://console.groq.com
 *   HUGGINGFACE_API_KEY = HuggingFace token from https://huggingface.co/settings/tokens
 *   GROQ_MODEL = Optional Groq model override (default "openai/gpt-oss-20b")
 *   HF_MODEL   = Optional HuggingFace model override (default "openai/gpt-oss-20b")
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
- Format responses as plain text with line breaks. Use "• " at the start of bullet lines — never use asterisks (*), hashes (#), backticks, or Markdown symbols.
- Do NOT use Markdown: no **bold**, no *italics*, no ### headings, no code fences. Just readable plain paragraphs and bullets.
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
 * v8.8 (Phase 9): contains the PRIMARY → HuggingFace fallback chain. When the
 * configured primary provider fails (missing key, network, timeout, rate
 * limit, 5xx, malformed response), the request is retried once against
 * HuggingFace Inference Providers so chat, resume review and deep analysis
 * all stay available. The provider reported to the caller is the one that
 * actually produced the response (`providerUsed`).
 *
 * NOTE: if the admin configured `huggingface` as AI_PROVIDER (single-provider
 * mode), there is nothing to fall back to — the HF error surfaces directly.
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

  // Single-provider mode (huggingface or unknown): no fallback available.
  if (provider === "huggingface") {
    const rawResponse = await callHuggingFaceAPI(systemPrompt, userPrompt, options);
    return { content: rawResponse, provider };
  }

  // Groq primary (the v8.8 default) with HuggingFace fallback.
  try {
    const rawResponse = await callGroqAPI(systemPrompt, userPrompt, options);
    return { content: rawResponse, provider: "groq" };
  } catch (primaryError) {
    console.error(
      `AI Provider: Groq failed — falling back to HuggingFace. Reason: ${primaryError.message}`
    );
    // No fallback when the fallback's own key is missing is handled by the
    // provider itself — surface a clear deployment error, never a key leak.
    if (!process.env.HUGGINGFACE_API_KEY) {
      throw new Error(
        "AI providers unavailable: Groq failed and HUGGINGFACE_API_KEY is not configured " +
        `(primary error: ${primaryError.message})`
      );
    }
    const rawResponse = await callHuggingFaceAPI(systemPrompt, userPrompt, options);
    return { content: rawResponse, provider: "huggingface" };
  }
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
 * Normalize raw chat text for the Flutter chat UI (v8.8 Phase 4).
 *
 * Turns accidental raw Markdown into readable plain text WITHOUT blindly
 * stripping characters that can legitimately appear in content (e.g. "C++",
 * "2*3=6", footnotes). Order matters:
 *
 *   1. Unescape literal \n / \t sequences some providers emit.
 *   2. Strip fenced code blocks (```...```) — their inner content is kept
 *      as plain text (code is displayed as-is when appropriate).
 *   3. Strip inline code backticks (`x`) — content is kept.
 *   4. Strip emphasis markers (**, *, __) only when they wrap a word/phrase
 *      and are NOT numeric/operator usages like "C++" or "a*b".
 *   5. Convert ATX headings (###, ##, #) to plain lines, collapsing the
 *      leading "#"s. Bold "### Heading" artifacts become "Heading ".
 *   6. Normalize Markdown-style bullet lines ("- item", "* item") and
 *      numbered lists ("1. item") to "• " bullets.
 *   7. Trim trailing whitespace per line and collapse >2 blank lines.
 *
 * The chat system prompt already forbids Markdown, so this is a defensive
 * cleanup pass, not a renderer. Resume-review/deep-analysis JSON parsing is
 * untouched — this function is applied ONLY to chat responses.
 *
 * @param {string} text - Raw chat response from the AI provider
 * @returns {string} Cleaned plain text
 */
function normalizeChatText(text) {
  if (!text || typeof text !== "string") return "";

  let output = text
    // 1. Literal escape sequences from some providers.
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "    ")
    // 2. Fenced code blocks — keep inner content as plain text.
    .replace(/```(?:[a-zA-Z0-9_+-]*)\s*\n?([\s\S]*?)\n?\s*```/g, "$1")
    // Strip inline code backticks.
    .replace(/`([^`\n]+)`/g, "$1");

  // 3. Emphasis: **bold** / __bold__ → content; *italic* / _italic_ →
  // content, but only when the markers wrap at least one word character and
  // are not part of a longer token (protects "C++", "a*b", "2*3").
  output = output.replace(
    /(\*\*|__)(?=\S)(.+?)(?<=\S)\1/g,
    "$2"
  );
  output = output.replace(
    /(?<![A-Za-z0-9*_])(\*|_)(?=\S)([A-Za-z][^*\n]*?)(?<=\S)\1(?![A-Za-z0-9*_])/g,
    "$2"
  );

  // 4. Headings: "### Heading" / "## Heading" / "# Heading" → plain line.
  output = output.replace(/^\s{0,3}(#{1,6})\s+(.+)$/gm, "$2");

  // 5. List bullets: "- item", "* item", "+ item" → "• item".
  output = output.replace(/^\s{0,3}[-*+]\s+/gm, "• ");

  // 6. Numbered lists: keep the numbering but normalize to "1. " spacing.
  output = output.replace(/^\s{0,3}(\d+)[.)]\s+/gm, "$1. ");

  // 7. Line cleanup.
  output = output
    .split("\n")
    .map((line) => line.replace(/\s+$/g, ""))
    .join("\n")
    // Collapse 3+ blank lines into 2.
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  return output;
}

/**
 * Generate AI chat response for the campus assistant.
 * Returns plain text (not JSON).
 *
 * v8.8 (Phase 4): the raw provider text passes through [normalizeChatText]
 * so the Flutter chat UI never sees raw Markdown artifacts (`*`, `**`,
 * `###`, fences, escaped `\n`). JSON-based resume paths are unaffected.
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
    response: normalizeChatText(content),
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
  normalizeChatText,
  SYSTEM_PROMPT,
  CHAT_SYSTEM_PROMPT,
  RESUME_REVIEW_SYSTEM_PROMPT,
  buildUserPrompt,
};
