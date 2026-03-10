/**
 * CampusConnect v6.95 - AI Response Normalizer
 *
 * Parses and normalizes raw AI responses from any provider into
 * the standard structured format expected by the Flutter client.
 *
 * Handles:
 * - JSON extraction from markdown code blocks
 * - Partial/malformed JSON recovery
 * - Field validation and defaults
 * - Type coercion for safety
 */

/**
 * Expected normalized response structure:
 * {
 *   summary: string,
 *   strengths: string[],
 *   weaknesses: string[],
 *   missingSkills: string[],
 *   careerSuggestions: string[],
 *   improvementRoadmap: {
 *     "30_days": string[],
 *     "60_days": string[]
 *   }
 * }
 */

/**
 * Normalize an AI response string into the structured format.
 *
 * @param {string} rawResponse - Raw text from the AI provider
 * @returns {object} Normalized analysis object
 * @throws {Error} If the response cannot be parsed at all
 */
function normalizeAIResponse(rawResponse) {
  if (!rawResponse || typeof rawResponse !== "string") {
    throw new Error("Empty or invalid AI response received");
  }

  // Step 1: Extract JSON from the response
  const jsonString = extractJSON(rawResponse);

  // Step 2: Parse the JSON
  let parsed;
  try {
    parsed = JSON.parse(jsonString);
  } catch (parseError) {
    console.error("Failed to parse AI response JSON:", parseError.message);
    console.error("Extracted text:", jsonString.substring(0, 500));

    // Try to salvage partial JSON
    parsed = attemptPartialParse(jsonString);

    if (!parsed) {
      throw new Error(
        `AI returned invalid JSON: ${parseError.message}. ` +
          `Raw response (first 200 chars): ${rawResponse.substring(0, 200)}`
      );
    }
  }

  // Step 3: Validate and normalize fields
  return {
    summary: ensureString(parsed.summary, "Resume analysis not available."),
    strengths: ensureStringArray(parsed.strengths, 5),
    weaknesses: ensureStringArray(parsed.weaknesses, 5),
    missingSkills: ensureStringArray(
      parsed.missingSkills || parsed.missing_skills,
      5
    ),
    careerSuggestions: ensureStringArray(
      parsed.careerSuggestions || parsed.career_suggestions,
      5
    ),
    improvementRoadmap: normalizeRoadmap(
      parsed.improvementRoadmap || parsed.improvement_roadmap
    ),
  };
}

/**
 * Extract JSON from a raw response that may contain markdown or extra text.
 *
 * @param {string} raw - Raw response string
 * @returns {string} Extracted JSON string
 */
function extractJSON(raw) {
  // Try 1: Response is already valid JSON (ideal case)
  const trimmed = raw.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    return trimmed;
  }

  // Try 2: JSON inside markdown code block ```json ... ```
  const codeBlockMatch = raw.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (codeBlockMatch && codeBlockMatch[1]) {
    return codeBlockMatch[1].trim();
  }

  // Try 3: Find first { and last } in the response
  const firstBrace = raw.indexOf("{");
  const lastBrace = raw.lastIndexOf("}");
  if (firstBrace !== -1 && lastBrace > firstBrace) {
    return raw.substring(firstBrace, lastBrace + 1);
  }

  // No JSON found - return as-is and let parser handle the error
  return trimmed;
}

/**
 * Attempt to parse partial or slightly malformed JSON.
 *
 * @param {string} jsonString - Possibly malformed JSON string
 * @returns {object|null} Parsed object or null if unrecoverable
 */
function attemptPartialParse(jsonString) {
  try {
    // Try fixing common issues: trailing commas
    const fixed = jsonString
      .replace(/,\s*}/g, "}")
      .replace(/,\s*\]/g, "]");
    return JSON.parse(fixed);
  } catch (_) {
    // Unrecoverable
    return null;
  }
}

/**
 * Ensure a value is a non-empty string.
 *
 * @param {*} value - Value to check
 * @param {string} fallback - Default value
 * @returns {string} Validated string
 */
function ensureString(value, fallback) {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }
  return fallback;
}

/**
 * Ensure a value is an array of non-empty strings.
 *
 * @param {*} value - Value to check
 * @param {number} maxItems - Maximum number of items
 * @returns {string[]} Validated string array
 */
function ensureStringArray(value, maxItems) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter((item) => typeof item === "string" && item.trim().length > 0)
    .map((item) => item.trim())
    .slice(0, maxItems);
}

/**
 * Normalize the improvement roadmap structure.
 *
 * @param {*} roadmap - Raw roadmap object
 * @returns {object} Normalized roadmap with 30_days and 60_days arrays
 */
function normalizeRoadmap(roadmap) {
  if (!roadmap || typeof roadmap !== "object") {
    return {
      "30_days": [],
      "60_days": [],
    };
  }

  return {
    "30_days": ensureStringArray(
      roadmap["30_days"] || roadmap["30days"] || roadmap.thirtyDays,
      5
    ),
    "60_days": ensureStringArray(
      roadmap["60_days"] || roadmap["60days"] || roadmap.sixtyDays,
      5
    ),
  };
}

module.exports = {
  normalizeAIResponse,
  extractJSON,
};
