"use strict";

/**
 * CampusConnect v9.3 — resume-review TEXT pipeline source contract.
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * The AI providers are text-in / text-out: Groq and HuggingFace take message
 * strings, never a PDF. A student's portfolio resume is a PDF in Cloud Storage,
 * so the ONLY way it can be reviewed is if the server converts it to text first
 * and scores THAT. Two defects made this worth pinning:
 *
 *   1. the ATS number was produced by the model — one resume scored 60, then
 *      55, then 55;
 *   2. with the generic role the app sends ("General / Entry Level") the model
 *      had no keywords to measure and settled on a constant 68 for a good and a
 *      bad resume alike.
 *
 * The fix scores the EXTRACTED TEXT with a pure rubric, which is only correct if
 * the text handed to the rubric is the text extracted from the PDF — not the
 * storage path, not the raw bytes, not a truncated fragment that never passed
 * the readability check. These tests assert the source that guarantees the chain
 * and fail if a later edit breaks it.
 *
 * Exactly like `hardening_source_contracts.test.js`, the invariant is a property
 * of the source, not a runtime behaviour a unit test can drive here (there is no
 * PDF fixture and no Firebase project in CI).
 *
 * Run: node --test test/resume_review_text_pipeline.test.js  (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const FUNCTIONS_ROOT = path.join(__dirname, "..");

/** Read a file under functions/ as text. */
function readFunctionsFile(relativePath) {
  return fs.readFileSync(path.join(FUNCTIONS_ROOT, relativePath), "utf8");
}

/** Strip `//` line comments so assertions run against executable text only. */
function stripLineComments(source) {
  return source
      .split("\n")
      .map((line) => {
        const commentAt = line.indexOf("//");
        return commentAt === -1 ? line : line.slice(0, commentAt);
      })
      .join("\n");
}

/**
 * The body of a `const NAME = ` template literal, without the fences.
 *
 * Lets a test assert on ONE prompt without matching the same words elsewhere in
 * the file (the review file mentions atsScore in several unrelated places).
 *
 * @param {string} source - Raw file contents
 * @param {string} name - Constant name
 * @returns {string}
 */
function templateConstant(source, name) {
  const header = `const ${name} = \``;
  const start = source.indexOf(header);
  assert.ok(start !== -1, `${name} must be declared as a template literal`);
  const bodyStart = start + header.length;
  const bodyEnd = source.indexOf("`;", bodyStart);
  assert.ok(bodyEnd !== -1, `${name} must be terminated`);
  return source.slice(bodyStart, bodyEnd);
}

const resumeReview = readFunctionsFile("ai/resumeReview.js");
const resumeReviewCode = stripLineComments(resumeReview);
const aiProvider = readFunctionsFile("ai/aiProvider.js");
const aiProviderCode = stripLineComments(aiProvider);

// ═════════════════════════════════════════════════════════════════════════
// The PDF → text half
// ═════════════════════════════════════════════════════════════════════════

test("resumeReview: the uploaded PDF is converted to text with pdf-parse", () => {
  assert.match(
      resumeReviewCode,
      /require\(\s*"pdf-parse\/lib\/pdf-parse\.js"\s*\)/,
      "the pure-JS PDF text extractor must be loaded",
  );
  assert.match(
      resumeReviewCode,
      /await\s+pdfParse\(\s*data\s*\)/,
      "the stored bytes must be PARSED — a PDF cannot be sent to a text model",
  );
  assert.match(
      resumeReviewCode,
      /parsed\.text/,
      "the extractor's text is what the pipeline continues with",
  );
});

test("resumeReview: the text is resolved BEFORE the AI call", () => {
  const extractIdx = resumeReviewCode.indexOf(
      "resumeTextFromStorage(userId, storagePath)");
  const aiIdx = resumeReviewCode.indexOf("generateResumeReviewAI(");
  assert.ok(extractIdx !== -1, "the uploaded path must extract text");
  assert.ok(aiIdx !== -1, "the pipeline must call the AI provider");
  assert.ok(
      extractIdx < aiIdx,
      "extraction must complete before the model is asked for anything — the " +
      "model is text-in only",
  );
});

test("resumeReview: the AI receives the extracted TEXT, never the PDF", () => {
  assert.match(
      resumeReviewCode,
      /generateResumeReviewAI\(\s*\n?\s*trimmedResume,/,
      "the extracted text must be the first argument to the AI call",
  );

  const callStart = resumeReviewCode.indexOf("generateResumeReviewAI(");
  const callArgs = resumeReviewCode.slice(callStart, callStart + 240);
  assert.doesNotMatch(
      callArgs,
      /storagePath/,
      "the storage path must never be handed to the text-only model",
  );
});

test("resumeReview: an image-only or too-short PDF is rejected, not reviewed", () => {
  assert.match(
      resumeReviewCode,
      /text\.length\s*<\s*RESUME_MIN_LENGTH/,
      "an empty / unscannable extraction must be detected",
  );
  assert.match(
      resumeReviewCode,
      /This resume appears to be image-based/,
      "the student must be told the PDF has no text layer instead of getting a " +
      "review of nothing",
  );
});

// ═════════════════════════════════════════════════════════════════════════
// The text → score half
// ═════════════════════════════════════════════════════════════════════════

test("aiProvider: the ATS score is computed by the deterministic rubric", () => {
  assert.match(
      aiProviderCode,
      /require\(\s*"\.\/atsScore"\s*\)/,
      "the scorer must be the local pure module, not a provider call",
  );
  assert.match(
      aiProviderCode,
      /const\s+rubric\s*=\s*scoreResume\(\s*resumeText,\s*targetRole\s*\)/,
      "the rubric must score the resume TEXT",
  );
  assert.match(
      aiProviderCode,
      /normalizeResumeReviewResponse\(\s*content,\s*rubric\.score\s*\)/,
      "the rubric score must be the value normalisation is given",
  );
});

test("aiProvider: the model is told not to return a score", () => {
  const prompt = templateConstant(aiProvider, "RESUME_REVIEW_SYSTEM_PROMPT");
  assert.match(
      prompt,
      /Do NOT return an "atsScore" field/,
      "the system prompt must forbid a model-supplied score",
  );
  assert.doesNotMatch(
      prompt,
      /"atsScore"\s*:/,
      "the JSON example must not show an atsScore field",
  );
});

test("aiProvider: a model-emitted atsScore is ignored when one is supplied", () => {
  assert.match(
      aiProviderCode,
      /const\s+atsScore\s*=\s*typeof\s+deterministicScore\s*===\s*"number"\s*\?/,
      "the supplied score must win over anything the model returns",
  );
});

test("resumeReview: the history document stores the review's own score", () => {
  assert.match(
      resumeReviewCode,
      /atsScore:\s*typeof\s+reviewResult\.atsScore\s*===\s*"number"/,
      "the persisted score must come from the review the student was shown",
  );
});
