"use strict";

/**
 * CampusConnect v9.2.5 — completion-token budgets for the AI providers.
 *
 * WHY THIS MODULE EXISTS
 * ----------------------
 * The configured models (`openai/gpt-oss-20b` on Groq, and the same model via
 * HuggingFace Inference Providers) are REASONING models: `max_tokens` bounds
 * the reasoning trace AND the answer together. Both providers previously sent
 * a flat `max_tokens: 2048` for every call, so on a structured request the
 * reasoning trace alone could consume the whole budget and the response came
 * back truncated or with an empty `content`. `JSON.parse` then failed inside
 * `normalizeResumeReviewResponse`, the callable rethrew, and the user saw a
 * generic failure — while the plain-text chat path (which has no strict parse)
 * continued to work. That asymmetry is exactly what "the resume reviewer is
 * broken but chat is fine" looks like.
 *
 * Structured JSON features now request a larger budget through
 * `options.maxTokens`, with the JSON default applied when `jsonMode` is on.
 */

/** Plain-text / chat completions. */
const DEFAULT_MAX_TOKENS = 2048;

/** Structured JSON completions (resume review, deep analysis, explanations). */
const JSON_MAX_TOKENS = 4096;

/**
 * Ceiling for the single truncation retry (see [escalateMaxTokens]).
 *
 * `openai/gpt-oss-20b` allows far more on both providers (Groq caps the
 * completion at 65536), so this is a safety ceiling rather than a model limit.
 */
const MAX_ESCALATED_TOKENS = 8192;

/**
 * Resolve the completion budget for one call.
 *
 * An explicit positive-integer `options.maxTokens` always wins. Otherwise JSON
 * mode gets the larger structured-output budget and plain text keeps the
 * original default, so no existing caller silently changes behaviour.
 *
 * @param {object} [options] - Provider options
 * @param {boolean} [options.jsonMode] - Whether JSON output was requested
 * @param {number} [options.maxTokens] - Explicit override
 * @returns {number} Token budget (always a positive integer)
 */
function resolveMaxTokens(options = {}) {
  const requested = options && options.maxTokens;
  if (Number.isInteger(requested) && requested > 0) return requested;
  return options && options.jsonMode === false ?
    DEFAULT_MAX_TOKENS :
    JSON_MAX_TOKENS;
}

/**
 * The budget to retry a TRUNCATED completion with, or `null` when the budget
 * cannot grow any further.
 *
 * This exists because of a defect confirmed in the deployed logs (2026-09-29):
 * a resume review sent to Groq with `max_tokens: 2048` came back
 *
 *   400 {"error":{"code":"json_validate_failed",
 *        "failed_generation":"max completion tokens reached before generating
 *                          a valid document"}}
 *
 * i.e. the reasoning trace consumed the entire budget and the JSON document was
 * never finished. Raising the budget is the correct response to that specific
 * failure — the model was not wrong, it was cut off — so the provider retries
 * ONCE with a doubled budget instead of failing the request.
 *
 * @param {number} current - The budget that was just exhausted
 * @returns {number|null} The larger budget, or null when already at the ceiling
 */
function escalateMaxTokens(current) {
  const from = Number.isInteger(current) && current > 0 ?
    current :
    JSON_MAX_TOKENS;
  if (from >= MAX_ESCALATED_TOKENS) return null;
  return Math.min(from * 2, MAX_ESCALATED_TOKENS);
}

module.exports = {
  DEFAULT_MAX_TOKENS,
  JSON_MAX_TOKENS,
  MAX_ESCALATED_TOKENS,
  resolveMaxTokens,
  escalateMaxTokens,
};
