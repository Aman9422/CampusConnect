/**
 * CampusConnect v9.0 — AI Career Coach
 *
 * The AI-first career-reasoning layer that REPLACES the deterministic
 * skill-gap engine. The deterministic code in this module handles ONLY the
 * things that should be deterministic:
 *
 *   - collecting/normalizing student career data (privacy-minimized)
 *   - computing a stable fingerprint of meaningful career data (staleness)
 *   - building the AI prompt (14-rule career guidance)
 *   - strictly validating AI output (supported types / priorities / fields)
 *   - gracefully degrading to a safe state on malformed AI responses
 *
 * The AI decides the actual career recommendations. It is connected through
 * the existing `callAIProvider` router (Groq primary → HuggingFace fallback)
 * from `functions/ai/aiProvider.js` — no second AI client is created.
 *
 * Schema (v9.0 only — a pipeline version bump would change this):
 *   {
 *     "careerReadiness": { "level": "strong|solid|developing|sparse", "summary": "..." },
 *     "careerFocus": "...",
 *     "recommendations": [{
 *       "type": "skill|portfolio|resume|project|experience|certification|
 *                achievement|profile|interview|jobSearch",
 *       "priority": "high|medium|low",
 *       "title": "...",
 *       "reason": "...",
 *       "action": "...",
 *       "whyItMatters": "...",
 *       "estimatedEffort": "..." (optional)
 *     }]
 *   }
 */

const {callAIProvider} = require('../ai/aiProvider');
const {extractJSON} = require('../ai/normalizeResponse');

/**
 * Bump ONLY when the stored analysis shape / meaning changes — the client
 * treats any cached analysis with a different analysisVersion as stale and
 * regenerates. Do NOT bump for prompt text tweaks.
 */
const ANALYSIS_VERSION = 1;

/**
 * Supported recommendation types the app can actually render + route to.
 * Everything else is rejected during validation (never displayed, never
 * stored). `skill` remains supported for genuinely-important missing-skills
 * the AI reasons about — but the AI is instructed to prefer strengthening /
 * building / deploying over adding technology tags.
 */
const SUPPORTED_RECOMMENDATION_TYPES = new Set([
  'skill',
  'portfolio',
  'resume',
  'project',
  'experience',
  'certification',
  'achievement',
  'profile',
  'interview',
  'jobSearch',
]);

const SUPPORTED_PRIORITIES = new Set(['high', 'medium', 'low']);

const SUPPORTED_READINESS_LEVELS = new Set([
  'strong',
  'solid',
  'developing',
  'sparse',
]);

/**
 * Max items the client UI can ever show (dashboard shows top 2–3; the full
 * screen shows all valid ones). Bounded to keep prompts small too.
 */
const MAX_RECOMMENDATIONS = 5;
const MAX_RECOMMENDATIONS_SENT_TO_AI = 5;

/**
 * Privacy minimizers — keep the prompt small and never ship unrelated
 * personal data (passwords, auth tokens, internal ids, phone numbers,
 * emails, Firestore metadata) to the AI provider.
 */
const MAX_SKILLS = 25;
const MAX_PROJECTS = 6;
const MAX_EXPERIENCE = 4;
const MAX_CERTIFICATIONS = 6;
const MAX_ACHIEVEMENTS = 6;
const MAX_FIELD_LENGTH = 400; // per free-text item (description/projects)
const MAX_RESUME_SUMMARY = 2500; // resume summary sent to AI
const MAX_TOTAL_INPUT = 9000; // hard ceiling on the whole CareerAnalysisInput

// ============================================================
// PRIVACY-MINIMIZED INPUT BUILDING
// ============================================================

/** Normalize a scalar to a trimmed string. */
function cleanString(value, max = MAX_FIELD_LENGTH) {
  if (value === null || value === undefined) return '';
  const text = String(value).replace(/\s+/g, ' ').trim();
  return text.length > max ? text.substring(0, max) : text;
}

function cleanStringList(value, maxItems) {
  if (!Array.isArray(value)) return [];
  const out = [];
  for (const item of value) {
    const text = cleanString(item);
    if (text && !out.includes(text)) out.push(text);
    if (out.length >= maxItems) break;
  }
  return out;
}

/**
 * Build the privacy-minimized `CareerAnalysisInput` from the raw user doc.
 *
 * Deliberately excludes: passwords, auth tokens, internal ids, phone/email,
 * timestamps, Firestore metadata, and any personal info beyond the career
 * signals the AI needs. Portfolio skill entries may be strings or
 * `{name}` maps (mirrors engine.extractUserSignals). Resume text is NOT
 * sent raw — only a short summary built from fileName / latestATSScore /
 * reviewCount (plus the latest review's overallAdvice when available).
 *
 * @param {object} userData - Raw `users/{uid}` document
 * @param {object} [portfolio] - Extracted portfolio map (defaults to
 *   `userData.portfolio`). Passed by the callable so the flattened-key
 *   fallback lives in one place (engine.extractPortfolio).
 * @returns {object} Normalized CareerAnalysisInput (never throws)
 */
function buildCareerAnalysisInput(userData, portfolio = userData && userData.portfolio) {
  if (!userData || typeof userData !== 'object') userData = {};
  if (!portfolio || typeof portfolio !== 'object') portfolio = {};

  const career = userData.career && typeof userData.career === 'object'
    ? userData.career
    : {};
  const academic = userData.academic && typeof userData.academic === 'object'
    ? userData.academic
    : {};
  const prefs = portfolio.preferences && typeof portfolio.preferences === 'object'
    ? portfolio.preferences
    : {};
  const resume = portfolio.resume && typeof portfolio.resume === 'object'
    ? portfolio.resume
    : {};

  const preferredRoles = Array.isArray(prefs.preferredRoles) ? prefs.preferredRoles : [];
  const interests = Array.isArray(career.interests) ? career.interests : [];

  // Portfolio skills may be strings or {name} maps.
  const rawPortfolioSkills = Array.isArray(portfolio.skills) ? portfolio.skills : [];
  const portfolioSkillNames = rawPortfolioSkills.map((s) =>
    typeof s === 'string' ? s : (s && typeof s === 'object' ? s.name : ''),
  );

  const projects = Array.isArray(portfolio.projects) ? portfolio.projects : [];
  const experience = Array.isArray(portfolio.experience) ? portfolio.experience : [];
  const certifications = Array.isArray(portfolio.certifications) ? portfolio.certifications : [];
  const achievements = Array.isArray(portfolio.achievements) ? portfolio.achievements : [];

  const atsScore = typeof resume.latestATSScore === 'number'
    ? Math.max(0, Math.min(100, Math.round(resume.latestATSScore)))
    : null;

  // Resume summary — metadata only + the latest review's overall advice
  // (the review is already stored on the user's own doc; only a short,
  // career-relevant excerpt is forwarded — never the full resume text).
  const resumeSummaryParts = [];
  if (cleanString(resume.fileName)) resumeSummaryParts.push(cleanString(resume.fileName, 120));
  if (atsScore !== null) resumeSummaryParts.push(`Latest ATS score: ${atsScore}/100`);
  if (typeof resume.reviewCount === 'number' && resume.reviewCount > 0) {
    resumeSummaryParts.push(`${resume.reviewCount} resume review(s) completed`);
  }

  const input = {
    careerGoal: cleanString(
      preferredRoles[0] ||
      prefs.careerObjective ||
      career.careerInterest ||
      userData.careerInterest ||
      interests[0] ||
      '',
      120,
    ),
    academicYear: Number(academic.year) || 0,
    skills: cleanStringList(
      [...new Set([...(Array.isArray(userData.skills) ? userData.skills : []), ...portfolioSkillNames])],
      MAX_SKILLS,
    ),
    projects: projects.slice(0, MAX_PROJECTS).map((p) => ({
      title: cleanString(p && p.title, 120),
      description: cleanString(p && p.description, 220),
      technologies: cleanStringList(p && p.technologies, 12),
    })),
    experience: experience.slice(0, MAX_EXPERIENCE).map((e) => ({
      role: cleanString(e && e.role, 120),
      company: cleanString(e && e.company, 120),
      description: cleanString(e && e.description, 220),
    })),
    certifications: certifications.slice(0, MAX_CERTIFICATIONS).map((c) => ({
      title: cleanString(c && c.title, 120),
      issuer: cleanString(c && c.issuer, 120),
    })),
    achievements: achievements.slice(0, MAX_ACHIEVEMENTS).map((a) => ({
      title: cleanString(a && a.title, 120),
      description: cleanString(a && a.description, 200),
    })),
    resumeSummary: cleanString(resumeSummaryParts.join(' · '), MAX_RESUME_SUMMARY),
    atsScore,
    portfolioSummary: [
      `${portfolioSkillNames.length} skill(s)`,
      `${projects.length} project(s)`,
      `${experience.length} experience(s)`,
      `${certifications.length} certification(s)`,
      `${achievements.length} achievement(s)`,
      resume.fileName ? 'resume uploaded' : null,
    ].filter(Boolean).join(', '),
  };

  return input;
}

/**
 * Stable fingerprint of the MEANINGFUL career data that affects coaching.
 * Regeneration is allowed ONLY when this changes (or the student taps
 * "Re-analyze"). Never includes timestamps or arbitrary provider metadata —
 * widget rebuilds / dashboard refreshes can never change this fingerprint.
 *
 * @param {object} input - Output of buildCareerAnalysisInput
 * @returns {string} SHA-256 hex fingerprint
 */
function computeCareerInputFingerprint(input) {
  if (!input || typeof input !== 'object') input = {};
  const canonical = {
    careerGoal: input.careerGoal || '',
    academicYear: input.academicYear || 0,
    skills: input.skills || [],
    projects: input.projects || [],
    experience: input.experience || [],
    certifications: input.certifications || [],
    achievements: input.achievements || [],
    resumeSummary: input.resumeSummary || '',
    atsScore: input.atsScore === null || input.atsScore === undefined ? null : input.atsScore,
    portfolioSummary: input.portfolioSummary || '',
  };
  const crypto = require('crypto');
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(canonical))
    .digest('hex');
}

/**
 * True when the student has enough career evidence for a meaningful AI
 * analysis. A completely empty profile still gets a valid analysis (the AI
 * recommends completing profile/portfolio info — test case G), so this only
 * guards the "no student doc at all" / degenerate case.
 */
function hasAnyCareerData(input) {
  if (!input) return false;
  return Boolean(
    input.careerGoal ||
    (input.skills && input.skills.length > 0) ||
    (input.projects && input.projects.length > 0) ||
    (input.experience && input.experience.length > 0) ||
    (input.certifications && input.certifications.length > 0) ||
    (input.achievements && input.achievements.length > 0) ||
    input.atsScore !== null ||
    (input.resumeSummary && input.resumeSummary.length > 0),
  );
}

// ============================================================
// PROMPT (14-rule career guidance) — Phase 5 rules verbatim
// ============================================================

const CAREER_COACH_SYSTEM_PROMPT = `You are CampusConnect's AI Career Coach for college students. A student's normalized career data is provided as JSON. Decide the most useful next career actions for THIS student.

Return ONLY a valid JSON object — no markdown, no code fences, no extra text. The JSON must follow this EXACT structure:
{
  "careerReadiness": {
    "level": "strong" | "solid" | "developing" | "sparse",
    "summary": "2-3 sentence honest assessment of the student's overall career readiness based ONLY on the provided data"
  },
  "careerFocus": "A short single-line description of the student's primary career direction (or 'Undefined yet' when the data gives no signal)",
  "recommendations": [
    {
      "type": "portfolio" | "resume" | "project" | "skill" | "experience" | "certification" | "achievement" | "profile" | "interview" | "jobSearch",
      "priority": "high" | "medium" | "low",
      "title": "Concise action title (max ~8 words)",
      "reason": "1-2 sentences explaining why this action fits THIS student's profile",
      "action": "Concrete, specific next step the student can take",
      "whyItMatters": "1 sentence on the career impact",
      "estimatedEffort": "Short estimate, e.g. '2-3 hours', '1-2 weeks' (optional)"
    }
  ]
}

RULES (follow ALL of them):
1. NEVER recommend a skill the student already has.
2. Do not recommend a technology merely because it appears in a generic role requirement.
3. Consider the student's EXISTING STACK before recommending a new technology.
4. Prefer strengthening existing relevant skills when that provides more career value than learning an unrelated technology.
5. Consider the student's year/semester as context, not rigid rules: early-year -> fundamentals, projects, exploration; middle-year -> stronger projects, internships, specialization; final-year -> placement preparation, resume, interviews, portfolio quality, job readiness.
6. Consider project QUALITY, not just project count. A thin project with no description or technologies weakens the portfolio regardless of count.
7. Consider experience and certifications as evidence, not requirements.
8. Consider resume/ATS information when available.
9. Consider the target role / career goal.
10. Recommendations must be realistically achievable for a college student.
11. Return 3-5 HIGH-VALUE recommendations — never 10-20. Quality over quantity.
12. Prioritize recommendations: only 1-2 should be "high"; the rest "medium"; avoid "low" unless genuinely useful.
13. If the student is already strong in an area, say so explicitly instead of recommending unnecessary learning.
14. You are ALLOWED to say: "No new skill is necessary right now. Focus on building/deploying/improving your existing projects."

If the student has very little data, DO NOT invent experience, skills, certificates, or achievements. Recommend completing missing profile/portfolio information or give limited guidance from the available data only.

Use ONLY these recommendation types: portfolio, resume, project, skill, experience, certification, achievement, profile, interview, jobSearch. Never invent other types.`;

/**
 * Build the user prompt containing the normalized career input.
 *
 * @param {object} input - CareerAnalysisInput from buildCareerAnalysisInput
 * @returns {string} User prompt with the JSON payload
 */
function buildCareerCoachPrompt(input) {
  return `Analyze the following normalized student career data and return your recommendations as strict JSON per the system instructions.

STUDENT CAREER DATA (JSON):
${JSON.stringify(input)}

Return ONLY the JSON object.`;
}

// ============================================================
// STRICT VALIDATION (never trust raw AI output)
// ============================================================

/**
 * Validate + sanitize a raw AI career-coach response.
 *
 * Returns a fully-typed analysis object or `null` when the response is
 * unusable (caller falls back to a safe state — never crashes the
 * dashboard).
 *
 * Safety contract (mirrors ai_explanations.validateExplanations):
 *   - Only the exact supported types / priorities / readiness levels survive.
 *   - Every string is trimmed and length-bounded.
 *   - Duplicate recommendation types are deduplicated (only the first with a
 *     given type is kept — the AI can't spam 5 portfolio rows).
 *   - Allowed key set is fixed; unknown keys are dropped (never echoed).
 *   - At least 1 valid recommendation OR a valid readiness summary must
 *     survive; otherwise the analysis is rejected.
 *
 * @param {string} rawContent - Raw AI response text
 * @returns {object|null} Validated analysis object
 */
function validateCareerCoachResponse(rawContent) {
  if (!rawContent || typeof rawContent !== 'string') return null;

  let parsed;
  try {
    parsed = JSON.parse(extractJSON(rawContent));
  } catch (parseError) {
    console.error(
        'validateCareerCoachResponse: could not parse AI JSON',
        parseError.message
    );
    return null;
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;

  // careerReadiness
  const readiness = parsed.careerReadiness;
  let readinessLevel = null;
  let readinessSummary = '';
  if (readiness && typeof readiness === 'object') {
    const rawLevel = cleanString(readiness.level, 20).toLowerCase();
    if (SUPPORTED_READINESS_LEVELS.has(rawLevel)) readinessLevel = rawLevel;
    readinessSummary = cleanString(readiness.summary, 600);
  }

  // careerFocus
  let careerFocus = cleanString(parsed.careerFocus, 200);
  if (careerFocus.length === 0) careerFocus = null;

  // recommendations — strict whitelist + dedupe by type
  const recommendations = [];
  const seenTypes = new Set();
  const rawRecs = Array.isArray(parsed.recommendations) ? parsed.recommendations : [];
  for (const rec of rawRecs) {
    if (!rec || typeof rec !== 'object') continue;
    if (recommendations.length >= MAX_RECOMMENDATIONS) break;

    const type = cleanString(rec.type, 30).toLowerCase();
    if (!SUPPORTED_RECOMMENDATION_TYPES.has(type)) continue;
    if (seenTypes.has(type)) continue; // dedupe by type

    const priority = cleanString(rec.priority, 10).toLowerCase();
    if (!SUPPORTED_PRIORITIES.has(priority)) continue;

    const title = cleanString(rec.title, 120);
    const reason = cleanString(rec.reason, 400);
    const action = cleanString(rec.action, 400);
    const whyItMatters = cleanString(rec.whyItMatters, 400);
    if (!title || !reason || !action) continue; // required fields

    seenTypes.add(type);
    recommendations.push({
      type,
      priority,
      title,
      reason,
      action,
      whyItMatters: whyItMatters || null,
      estimatedEffort: cleanString(rec.estimatedEffort, 80) || null,
    });
  }

  // Graceful safe state: an analysis is usable if it carries at least one
  // valid recommendation, or a readiness level + summary (client can show a
  // "career readiness" card even with zero actionable items).
  const hasReadiness = readinessLevel !== null && readinessSummary.length > 0;
  if (recommendations.length === 0 && !hasReadiness) {
    console.error(
        'validateCareerCoachResponse: analysis unusable ' +
        `(recs=${recommendations.length}, readiness=${readinessLevel})`
    );
    return null;
  }

  // Sort: high > medium > low (stable — keeps AI's internal order within
  // each priority band). The client renders the top items from this order.
  const priorityRank = {high: 0, medium: 1, low: 2};
  recommendations.sort((a, b) => priorityRank[a.priority] - priorityRank[b.priority]);

  return {
    careerReadiness: {
      level: readinessLevel || 'developing',
      summary: readinessSummary || 'Career readiness data is limited.',
    },
    careerFocus,
    recommendations,
    analysisVersion: ANALYSIS_VERSION,
  };
}

/**
 * Run the AI career-coach analysis for a normalized input.
 *
 * Uses the shared `callAIProvider` router (Groq primary → HuggingFace
 * fallback) — never a second AI client. The raw response is validated by
 * `validateCareerCoachResponse`; malformed output THROWS (the callable
 * catches, rolls back quota and returns a safe error — never a crash).
 *
 * @param {object} input - CareerAnalysisInput from buildCareerAnalysisInput
 * @returns {Promise<object>} Validated analysis (with `providerUsed`)
 * @throws {Error} When the AI call fails or the response is unusable
 */
async function generateCareerCoaching(input) {
  const result = await callAIProvider(
      CAREER_COACH_SYSTEM_PROMPT,
      buildCareerCoachPrompt(input),
      {jsonMode: true}
  );

  const validated = validateCareerCoachResponse(result.content);
  if (!validated) {
    throw new Error(
        `Career coach AI response invalid (provider: ${result.provider || 'unknown'})`
    );
  }

  return {
    ...validated,
    providerUsed: result.provider || null,
  };
}

module.exports = {
  ANALYSIS_VERSION,
  SUPPORTED_RECOMMENDATION_TYPES,
  SUPPORTED_PRIORITIES,
  SUPPORTED_READINESS_LEVELS,
  MAX_RECOMMENDATIONS,
  MAX_RECOMMENDATIONS_SENT_TO_AI,
  buildCareerAnalysisInput,
  computeCareerInputFingerprint,
  hasAnyCareerData,
  buildCareerCoachPrompt,
  validateCareerCoachResponse,
  generateCareerCoaching,
  CAREER_COACH_SYSTEM_PROMPT,
};
