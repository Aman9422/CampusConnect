"use strict";

/**
 * CampusConnect v9.2.5 — AI error-reporting and resume-retrieval contracts.
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * The regression it pins: **every** failure inside a Cloud Function reached the
 * client as an opaque `internal` / `INTERNAL`, because the codebase's
 * `new admin.functions.https.HttpsError(...)` convention referenced a provider
 * `firebase-admin` does not have. A resume reviewer that read the wrong
 * Storage bucket therefore looked identical to a quota rejection, a malformed
 * argument or a dead AI provider — no code, no message, no `usage` details.
 *
 * The tests below pin the three independent fixes that make the failure
 * legible and the uploaded-resume path work:
 *
 *   1. `helpers/https_error.js` — the real `HttpsError` class is attached to
 *      `admin.functions.https` (and `functions/index.js` does it before any
 *      feature module is required).
 *   2. `ai/resumeStorage.js` — the resume object is read from every plausible
 *      bucket name, and "absent" is distinguished from "unreadable".
 *   3. `ai/tokenBudget.js` — structured JSON calls get a budget that a
 *      reasoning model cannot silently spend entirely on its reasoning trace.
 *
 * Run:  node --test test/ai_error_reporting.test.js   (from functions/)
 */

require("./setup");

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const admin = require("firebase-admin");
const {
  HttpsError: RealHttpsError,
  installHttpsError,
} = require("../helpers/https_error");
const {
  RESUME_MAX_BYTES,
  resumeBucketCandidates,
  configuredBucketCandidates,
  downloadResumeBuffer,
  isNotFoundError,
} = require("../ai/resumeStorage");
const {
  DEFAULT_MAX_TOKENS,
  JSON_MAX_TOKENS,
  resolveMaxTokens,
} = require("../ai/tokenBudget");

const FUNCTIONS_ROOT = path.join(__dirname, "..");

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

const PROJECT_ID = "campusconnect-firebase-project";
const DEFAULT_BUCKET = `${PROJECT_ID}.firebasestorage.app`;
const LEGACY_BUCKET = `${PROJECT_ID}.appspot.com`;

// ═════════════════════════════════════════════════════════════════════════
// 1 — the real HttpsError reaches every failure site
// ═════════════════════════════════════════════════════════════════════════

test("https_error: the shim installs a WORKING HttpsError when the runtime has none", () => {
  const saved = admin.functions;
  try {
    // Reproduce the deployed runtime: firebase-admin exposes no `functions`
    // provider, so this property is absent.
    delete admin.functions;

    const installed = installHttpsError();

    assert.equal(
        typeof admin.functions.https.HttpsError,
        "function",
        "admin.functions.https.HttpsError must be constructible after install",
    );
    assert.equal(installed, RealHttpsError,
        "the installed class must be the real firebase-functions HttpsError");

    // The three fields the callable contract depends on.
    const error = new admin.functions.https.HttpsError(
        "resource-exhausted",
        "Monthly resume review limit reached (5/month).",
        {usage: {monthlyCount: 5, monthlyLimit: 5}},
    );
    assert.equal(error.code, "resource-exhausted");
    assert.equal(error.message, "Monthly resume review limit reached (5/month).");
    assert.deepEqual(error.details, {usage: {monthlyCount: 5, monthlyLimit: 5}});
    assert.ok(error instanceof admin.functions.https.HttpsError);

    // Idempotent.
    assert.equal(installHttpsError(), installed);
  } finally {
    admin.functions = saved;
  }
});

test("https_error: an existing HttpsError is never clobbered", () => {
  const existing = admin.functions.https.HttpsError;
  assert.equal(installHttpsError(), existing,
      "the unit-test stand-in must survive, so the deployed class is the only " +
      "one ever installed by this shim");
});

test("https_error: index.js installs the shim BEFORE requiring feature modules", () => {
  const source = stripLineComments(readFunctionsFile("index.js"));
  const installAt = source.indexOf("installHttpsError()");
  assert.ok(installAt !== -1,
      "functions/index.js must call installHttpsError()");

  const featureModules = [
    'require("./careerCoach")',
    'require("./ai/chat")',
    'require("./ai/resumeReview")',
    'require("./ai/deepAnalysis")',
    'require("./ai/chatDelete")',
    'require("./triggers")',
    'require("./schedulers")',
    'require("./recommendations/refresh")',
    'require("./placements")',
  ];
  for (const modulePath of featureModules) {
    const at = source.indexOf(modulePath);
    assert.ok(at !== -1, `index.js must require ${modulePath}`);
    assert.ok(
        installAt < at,
        `installHttpsError() must run before ${modulePath} is required`,
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 2 — the resume object is read from every plausible bucket
// ═════════════════════════════════════════════════════════════════════════

test("resumeStorage: candidate buckets cover both default namings, deduped", () => {
  const candidates = resumeBucketCandidates({
    configuredBucket: LEGACY_BUCKET,
    projectId: PROJECT_ID,
  });

  // The admin-configured name first, then the current default naming —
  // and nothing is repeated.
  assert.ok(candidates.includes(LEGACY_BUCKET));
  assert.ok(candidates.includes(DEFAULT_BUCKET));
  assert.equal(candidates[0], LEGACY_BUCKET,
      "the bucket Firebase Admin itself resolves must be tried first");
  assert.equal(new Set(candidates).size, candidates.length,
      "candidate buckets must be deduped");
});

test("resumeStorage: an STORAGE_BUCKET override is tried first", () => {
  const previous = process.env.STORAGE_BUCKET;
  process.env.STORAGE_BUCKET = "override-bucket";
  try {
    const candidates = resumeBucketCandidates({projectId: PROJECT_ID});
    assert.equal(candidates[0], "override-bucket");
  } finally {
    if (previous === undefined) delete process.env.STORAGE_BUCKET;
    else process.env.STORAGE_BUCKET = previous;
  }
});

test("resumeStorage: no project, no override and no configured bucket yields no candidates", () => {
  const previous = process.env.STORAGE_BUCKET;
  delete process.env.STORAGE_BUCKET;
  try {
    assert.deepEqual(resumeBucketCandidates({}), []);
    assert.deepEqual(resumeBucketCandidates({configuredBucket: "   "}), []);
  } finally {
    if (previous !== undefined) process.env.STORAGE_BUCKET = previous;
  }
});

test("resumeStorage: the configured-bucket lookup never throws without an app", () => {
  // The unit-test shim replaces firebase-admin wholesale, so `admin.app` is
  // absent — the resolver must degrade to the env-derived candidates instead of
  // throwing inside the review path.
  assert.ok(Array.isArray(configuredBucketCandidates()));
});

test("resumeStorage: Storage 404 shapes are recognised as not-found", () => {
  assert.ok(isNotFoundError({code: 404}));
  assert.ok(isNotFoundError({code: "404"}));
  assert.ok(isNotFoundError({code: "not-found"}));
  assert.ok(isNotFoundError({statusCode: 404}));
  assert.ok(isNotFoundError(new Error("No such object: bucket/path")));
  assert.ok(isNotFoundError(new Error("Not Found")));
  assert.ok(!isNotFoundError(new Error("Permission denied")));
  assert.ok(!isNotFoundError(null));
  assert.ok(!isNotFoundError({code: 403}));
});

test("resumeStorage: the 5 MB ceiling matches the client StorageService", () => {
  const clientSource = fs.readFileSync(
      path.join(FUNCTIONS_ROOT, "..", "lib/services/storage/storage_service.dart"),
      "utf8",
  );
  assert.match(clientSource, /maxResumeBytes = 5 \* 1024 \* 1024/);
  assert.equal(RESUME_MAX_BYTES, 5 * 1024 * 1024);
});

// ═════════════════════════════════════════════════════════════════════════
// 3 — structured JSON calls get a budget a reasoning model cannot eat whole
// ═════════════════════════════════════════════════════════════════════════

test("tokenBudget: JSON mode gets the larger budget, plain text keeps the default", () => {
  assert.equal(resolveMaxTokens({jsonMode: true}), JSON_MAX_TOKENS);
  assert.equal(resolveMaxTokens({jsonMode: false}), DEFAULT_MAX_TOKENS);
  assert.equal(resolveMaxTokens({}), JSON_MAX_TOKENS,
      "the providers default jsonMode to true");
  assert.ok(JSON_MAX_TOKENS > DEFAULT_MAX_TOKENS,
      "a structured payload needs more room than a chat reply");
  assert.ok(Number.isInteger(JSON_MAX_TOKENS) && JSON_MAX_TOKENS > 0);
  assert.ok(Number.isInteger(DEFAULT_MAX_TOKENS) && DEFAULT_MAX_TOKENS > 0);
});

test("tokenBudget: an explicit positive override wins, invalid ones are ignored", () => {
  assert.equal(resolveMaxTokens({jsonMode: false, maxTokens: 8192}), 8192);
  assert.equal(resolveMaxTokens({jsonMode: true, maxTokens: 1024}), 1024);

  for (const invalid of [0, -1, 1.5, "2048", null, undefined, NaN]) {
    assert.equal(
        resolveMaxTokens({jsonMode: true, maxTokens: invalid}),
        JSON_MAX_TOKENS,
        `maxTokens=${String(invalid)} must not override the JSON budget`,
    );
  }
});

test("tokenBudget: both providers send the resolved budget, never a constant", () => {
  for (const provider of ["ai/groqProvider.js", "ai/huggingfaceProvider.js"]) {
    const source = stripLineComments(readFunctionsFile(provider));
    assert.match(
        source,
        /max_tokens:\s*maxTokens,/,
        `${provider} must send the resolved completion budget`,
    );
    assert.doesNotMatch(
        source,
        /max_tokens:\s*MAX_TOKENS,/,
        `${provider} must not hard-code a flat max_tokens for every call`,
    );
    assert.match(
        source,
        /resolveMaxTokens\(\{\.\.\.options,\s*jsonMode:\s*useJsonMode\}\)/,
        `${provider} must derive the budget from the call's jsonMode`,
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 4 — the resume-review callable uses the bucket-resilient reader
// ═════════════════════════════════════════════════════════════════════════

test("resumeReview: the uploaded PDF is read through the bucket-resilient reader", () => {
  const source = stripLineComments(readFunctionsFile("ai/resumeReview.js"));

  assert.match(
      source,
      /const\s+download\s*=\s*await\s+downloadResumeBuffer\(\s*storagePath\s*\)/,
      "reviewResume must read the object via downloadResumeBuffer(storagePath)",
  );
  assert.match(
      source,
      /require\("\.\/resumeStorage"\)/,
      "resumeReview must import the bucket-resilient reader",
  );
  assert.doesNotMatch(
      source,
      /admin\.storage\(\)\.bucket\(\)\.file\(/,
      "the nameless `admin.storage().bucket()` lookup must not come back — it "
      + "resolves the legacy `<project>.appspot.com` bucket while the app "
      + "uploads to `<project>.firebasestorage.app`",
  );
});

test("resumeReview: a missing resume is reported as not-found, not as internal", () => {
  const source = stripLineComments(readFunctionsFile("ai/resumeReview.js"));

  assert.match(
      source,
      /download\.reason\s*===\s*"not-found"[\s\S]{0,200}?"not-found",/,
      "an absent resume object must raise a `not-found` HttpsError with an "
      + "actionable message",
  );
  assert.match(
      source,
      /download\.reason\s*===\s*"too-large"[\s\S]{0,200}?"invalid-argument",/,
      "an oversized resume must raise `invalid-argument`",
  );
});

// ═════════════════════════════════════════════════════════════════════════
// 5 — the reader PROBES the buckets and reports a typed outcome
// ═════════════════════════════════════════════════════════════════════════

/** Storage "object not found" as @google-cloud/storage raises it. */
function notFoundError(bucketName, objectPath) {
  const error = new Error(`No such object: ${bucketName}/${objectPath}`);
  error.code = 404;
  return error;
}

/**
 * Replace `admin.storage()` with a scripted double.
 *
 * [objectsByBucket] maps a bucket name to `{buffer, size}`; a bucket missing
 * from the map answers 404 for every object, exactly as an empty bucket does.
 * An entry may instead be `{error}` to make `getMetadata` fail with a non-404
 * error (permission, network, ...).
 *
 * `size` is passed through `String()`, because the Storage API reports the
 * object size as a string.
 */
function stubStorage(objectsByBucket) {
  const previous = admin.storage;
  const bucketsAsked = [];

  admin.storage = () => ({
    bucket(name) {
      bucketsAsked.push(name);
      return {
        file(objectPath) {
          return {
            async getMetadata() {
              const entry = objectsByBucket[name];
              if (!entry) throw notFoundError(name, objectPath);
              if (entry.error) throw entry.error;
              return [{size: String(entry.size)}];
            },
            async download() {
              return [objectsByBucket[name].buffer];
            },
          };
        },
      };
    },
  });

  return {
    bucketsAsked,
    restore() {
      if (previous === undefined) delete admin.storage;
      else admin.storage = previous;
    },
  };
}

/** Run [body] with the given environment variables applied, then restore them. */
async function withEnv(vars, body) {
  const previous = {};
  for (const [key, value] of Object.entries(vars)) {
    previous[key] = process.env[key];
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
  try {
    return await body();
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

const RESUME_PATH = "resumes/user-1/latest.pdf";

test("resumeStorage: a file in the CURRENT default bucket is found even when the configured bucket is the legacy one", async () => {
  // The deployment that motivated the reader: the bucket Firebase Admin
  // resolves is `<project>.appspot.com` while the client uploaded to
  // `<project>.firebasestorage.app`. The old nameless lookup answered 404 here;
  // probing finds the object.
  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: LEGACY_BUCKET,
  }, async () => {
    const stub = stubStorage({
      [DEFAULT_BUCKET]: {buffer: Buffer.from("%PDF-1.4 resume"), size: 16},
    });
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, true);
      assert.equal(result.bucket, DEFAULT_BUCKET,
          "the object must be reported from the bucket that actually held it");
      assert.equal(result.buffer.toString(), "%PDF-1.4 resume");
      assert.deepEqual(stub.bucketsAsked, [LEGACY_BUCKET, DEFAULT_BUCKET],
          "the configured name is tried first, then the current naming");
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: an object absent from every bucket reports not-found and the buckets tried", async () => {
  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({});
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, false);
      assert.equal(result.reason, "not-found");
      assert.deepEqual(result.bucketsTried, [DEFAULT_BUCKET, LEGACY_BUCKET]);
      assert.deepEqual(stub.bucketsAsked, [DEFAULT_BUCKET, LEGACY_BUCKET]);
      assert.match(result.detail, /absent from every candidate bucket/);
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: no resolvable bucket name reports not-found instead of throwing", async () => {
  await withEnv({
    GCLOUD_PROJECT: undefined,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({});
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, false);
      assert.equal(result.reason, "not-found");
      assert.deepEqual(result.bucketsTried, []);
      assert.equal(stub.bucketsAsked.length, 0,
          "no bucket should be contacted when none can be named");
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: an oversized object reports too-large", async () => {
  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({
      [DEFAULT_BUCKET]: {
        buffer: Buffer.alloc(32),
        size: RESUME_MAX_BYTES + 1,
      },
    });
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, false);
      assert.equal(result.reason, "too-large");
      assert.equal(stub.bucketsAsked.length, 1,
          "an oversized object is not an invitation to try another bucket");
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: an empty object reports unreadable, not not-found", async () => {
  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({
      [DEFAULT_BUCKET]: {buffer: Buffer.alloc(0), size: 0},
    });
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, false);
      assert.equal(result.reason, "unreadable");
      assert.match(result.detail, /is empty/);
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: a non-404 read failure reports unreadable and stops probing", async () => {
  const permissionDenied = new Error("Permission denied");
  permissionDenied.code = 403;

  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({[DEFAULT_BUCKET]: {error: permissionDenied}});
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, false);
      assert.equal(result.reason, "unreadable");
      assert.match(result.detail, /Permission denied/);
      assert.deepEqual(stub.bucketsAsked, [DEFAULT_BUCKET],
          "a bucket that answered with a real error is not 'not found' — do " +
          "not mask it by trying the next bucket");
    } finally {
      stub.restore();
    }
  });
});

test("resumeStorage: an object with no reported size is still downloaded", async () => {
  await withEnv({
    GCLOUD_PROJECT: PROJECT_ID,
    GCP_PROJECT: undefined,
    STORAGE_BUCKET: undefined,
  }, async () => {
    const stub = stubStorage({
      [DEFAULT_BUCKET]: {buffer: Buffer.from("pdf"), size: undefined},
    });
    try {
      const result = await downloadResumeBuffer(RESUME_PATH);

      assert.equal(result.ok, true,
          "a missing size must not be read as an oversized object");
      assert.equal(result.buffer.toString(), "pdf");
    } finally {
      stub.restore();
    }
  });
});
