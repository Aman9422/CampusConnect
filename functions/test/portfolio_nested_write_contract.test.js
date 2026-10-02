"use strict";

/**
 * CampusConnect v9.2.7 — PORTFOLIO NESTED-WRITE source contract.
 *
 * The defect this pins: every portfolio writer used DOT-NOTATION keys in a
 * `set(…, {merge: true})` payload (`"portfolio.resume.reviewCount"`,
 * `"portfolio.skills"`, …). Dot notation is a feature of `update()`; in a
 * merge-set payload a key containing a dot is stored as a LITERAL root-level
 * field NAME.
 *
 * Consequences on-device:
 *   - replacing/removing a resume showed the success snackbar (Storage really
 *     was written/deleted) while the stored metadata — and therefore the
 *     dashboard card — never changed;
 *   - the meta-1 note in the app counted zero reviews and showed no ATS score,
 *     because `portfolio.resume.reviewCount` / `…latestATSScore` from
 *     `onResumeReviewCreatedRefreshMatches` landed beside the nested map;
 *   - "Open Resume" returned `403 Permission denied`, because the value the
 *     app opened was the download URL cached from a PREVIOUS upload (whose
 *     token had been rotated by the overwrite at the same storage path).
 *
 * The nested shape is what every reader uses — the Dart reader
 * (`_extractPortfolioMap`), the recommendation engine and
 * `isResumeReviewMetadataOnlyChange` in `functions/helpers/shared.js` all
 * read `portfolio.resume.*`. These tests assert the SOURCE of every writer
 * stays on that shape. Written as a source contract (like
 * `hardening_source_contracts.test.js`) because a Firestore write payload has
 * no runtime behaviour this repository can exercise without an emulator.
 *
 * Run:  node --test test/portfolio_nested_write_contract.test.js  (functions/)
 */

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const FUNCTIONS_ROOT = path.join(__dirname, "..");
const REPO_ROOT = path.join(FUNCTIONS_ROOT, "..");

function readRepoFile(relativePath) {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
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

const triggerSource = readRepoFile("functions/triggers/index.js");
const triggerCode = stripLineComments(triggerSource);

const portfolioServiceSource = readRepoFile(
    "lib/services/firestore/portfolio_service.dart",
);
const portfolioServiceCode = stripLineComments(portfolioServiceSource);

/**
 * A string literal whose value is a dotted portfolio path — the exact shape
 * that gets stored as a flat field. Matches `"portfolio.resume"`,
 * `'portfolio.skills'`, `"portfolio.resume.reviewCount"`, … (both quote
 * styles) but NOT a Dart/PHP-style interpolation such as `` `portfolio.${k}` ``
 * which the second group of tests rejects separately.
 */
const DOTTED_PORTFOLIO_LITERAL = /["']portfolio\.[A-Za-z]/;

test("resume-review trigger writes the NESTED map, not dotted keys", () => {
  assert.ok(
      triggerCode.includes("{portfolio: {resume: resumeMerge}}"),
      "onResumeReviewCreatedRefreshMatches must set {portfolio: {resume: {...}}}" +
        " with merge:true; a nested map merges into the same section the app and" +
        " the engine read.",
  );
});

test("no Cloud Function writes a literal dotted portfolio key", () => {
  const match = DOTTED_PORTFOLIO_LITERAL.exec(triggerCode);
  assert.strictEqual(
      match,
      null,
      `a literal dotted portfolio key is stored as a flat root field and is ` +
        `invisible to every reader: found ${match && match[0]}`,
  );
});

test("the trigger's resume counters keep increment/merge semantics", () => {
  // The counters must still be atomic increments written through the nested
  // map; a plain number here would lose concurrent reviews.
  assert.ok(
      triggerCode.includes("reviewCount: admin.firestore.FieldValue.increment(1)"),
      "reviewCount must remain FieldValue.increment(1) inside the nested map",
  );
  assert.ok(
      triggerCode.includes("latestMissingKeywords: missingKeywords"),
      "the review signal must be persisted on the document under the nested map",
  );
});

test("the client builds its write payload as one nested portfolio map", () => {
  assert.ok(
      portfolioServiceCode.includes("'portfolio': changedSections"),
      "buildPortfolioWritePayload must nest the changed sections under 'portfolio'",
  );
  assert.ok(
      portfolioServiceCode.includes("'metadata': <String, dynamic>{'updatedAt'"),
      "the updatedAt stamp must be a nested metadata map, not a dotted key",
  );
});

test("no Dart portfolio write uses a dotted key or interpolated dotted path", () => {
  // `'portfolio.$key'` is the exact construction that shipped broken.
  assert.ok(
      !portfolioServiceCode.includes("'portfolio.$"),
      "savePortfolio must not interpolate 'portfolio.$key' write paths",
  );
  assert.ok(
      !portfolioServiceCode.includes("'portfolio.subtitle"),
      "no section may be addressed through a dotted string path",
  );
  const match = DOTTED_PORTFOLIO_LITERAL.exec(portfolioServiceCode);
  assert.strictEqual(
      match,
      null,
      `unexpected dotted portfolio literal in portfolio_service.dart: ` +
        `${match && match[0]}`,
  );
});
