/**
 * CampusConnect v8.9 — AI Explanation Enrichment for Recommendations
 *
 * AI is used ONLY to enrich top-N recommendation explanations (semantic
 * relevance + nuanced career matching). Hard constraints (eligibility,
 * security) are decided BEFORE this module by the deterministic engine in
 * `engine.js` — AI can never override them.
 *
 * Uses the existing v8.8 AI router (`callAIProvider`) — no new AI client.
 * The recommendation path NEVER touches the Resume Review quota
 * (`resume_usage/{uid}`). This module is best-effort and falls back to the
 * deterministic `reason` field when AI fails, times out, or returns a
 * malformed payload.
 */

const {callAIProvider} = require('../ai/aiProvider');

/**
 * System prompt: strict JSON, single object of explanations keyed by the
 * exact recommendation document id. The prompt forbids eligibility claims.
 */
const EXPLANATION_SYSTEM_PROMPT = `You are a campus career guidance expert. You will receive a JSON list of a student's career recommendations (role matches, placement matches, skill gaps) that were already computed deterministically. For EACH recommendation, write a friendly, specific explanation (1-2 sentences) of WHY it fits this student's profile.

Rules:
- Return ONLY a valid JSON object: { "explanations": { "<recId>": "explanation text" } }.
- Use ONLY the recommendation data provided. Never invent skills, achievements, grades, or offers.
- Never state eligibility, ATS scores, or hiring decisions as facts you decided — only describe the profile alignment shown in the data.
- Keep each explanation under 180 characters.
- No markdown, no code fences.`;

/**
 * Build the bounded user prompt for the top-N recommendations.
 */
function buildExplanationsPrompt(recommendations) {
  const payload = recommendations.map((r) => ({
    id: r.id,
    type: r.type,
    title: r.title,
    score: r.score,
    reason: r.reason || '',
    skillsMatched: r.skillsMatched || [],
    skillsMissing: r.skillsMissing || [],
    targetRole: r.targetRole || null,
  }));
  return JSON.stringify(payload);
}

/**
 * Validate + sanitize the AI explanation payload.
 *
 * Mirrors the `normalizeResumeReviewResponse` safety pattern: never trust
 * raw AI output. Returns a map of {recId: explanation} containing ONLY
 * non-empty strings ≤ 200 chars, restricted to the recommendation ids we
 * actually sent.
 *
 * @param {string} rawContent - Raw AI response text
 * @param {Set<string>} allowedIds - Recommendation ids we asked about
 * @returns {Map<string, string>}
 */
function validateExplanations(rawContent, allowedIds) {
  const safe = new Map();
  if (!rawContent || typeof rawContent !== 'string') return safe;

  let parsed;
  try {
    parsed = JSON.parse(rawContent);
  } catch (parseError) {
    // Try to recover a JSON object from markdown/extra text.
    const firstBrace = rawContent.indexOf('{');
    const lastBrace = rawContent.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace > firstBrace) {
      const extracted = rawContent.substring(firstBrace, lastBrace + 1);
      try {
        parsed = JSON.parse(extracted);
      } catch (_) {
        console.error(
            'validateExplanations: could not parse AI explanation JSON',
            parseError.message
        );
        return safe;
      }
    } else {
      console.error(
          'validateExplanations: AI returned no JSON object',
          parseError.message
      );
      return safe;
    }
  }

  const explanations = parsed && parsed.explanations;
  if (!explanations || typeof explanations !== 'object') return safe;

  for (const key of Object.keys(explanations)) {
    if (!allowedIds.has(key)) continue; // never echo an id we didn't ask about
    const text = typeof explanations[key] === 'string'
        ? explanations[key].trim()
        : '';
    if (text.length === 0) continue;
    safe.set(key, text.length > 200 ? text.substring(0, 200) : text);
  }
  return safe;
}

/**
 * Enrich the top-N recommendations with AI explanations.
 *
 * Best-effort: on any failure the recommendation objects keep their
 * deterministic `reason`. Never throws.
 *
 * @param {Array<object>} recommendations - Deterministic recommendation payloads
 * @param {number} [limit=5] - How many recommendations to ask about
 * @returns {Promise<Array<object>>} Same array (mutated in place),
 *   with `aiExplanation` set only when AI produced valid text.
 */
async function enrichRecommendationExplanations(recommendations, limit = 5) {
  // Only enrich role/placement/skill recommendations — never the legacy
  // mentor/job/chat rows (they carry their own concise descriptions).
  const enrichable = recommendations.filter(
      (r) => r.type === 'role' || r.type === 'placement' || r.type === 'skill'
  );
  if (enrichable.length === 0) return recommendations;

  const target = enrichable.slice(0, limit);
  const allowedIds = new Set(target.map((r) => r.id));

  try {
    const result = await callAIProvider(
        EXPLANATION_SYSTEM_PROMPT,
        buildExplanationsPrompt(target),
        {jsonMode: true}
    );
    const explanations = validateExplanations(result.content, allowedIds);

    for (const rec of target) {
      const aiText = explanations.get(rec.id);
      if (aiText) {
        rec.aiExplanation = aiText;
        rec.aiProviderUsed = result.provider || null;
      }
    }
  } catch (aiError) {
    // Deterministic fallback — the stored `reason` remains authoritative.
    console.error(
        'enrichRecommendationExplanations: AI enrichment failed, using deterministic reasons:',
        aiError.message
    );
  }

  return recommendations;
}

module.exports = {
  enrichRecommendationExplanations,
  validateExplanations,
};
