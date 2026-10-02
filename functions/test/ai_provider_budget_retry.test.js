"use strict";

/**
 * CampusConnect v9.2.5 — completion-budget retry behaviour of the AI providers.
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * The deployed logs (2026-09-29) recorded the resume reviewer failing with
 *
 *   400 {"error":{"code":"json_validate_failed",
 *        "failed_generation":"max completion tokens reached before generating
 *                          a valid document"}}
 *
 * `openai/gpt-oss-20b` is a reasoning model, so its `max_tokens` budget covers
 * the reasoning trace AND the answer; at 2048 the trace consumed everything and
 * the JSON document was never closed. The reviewer only appeared to work
 * because the HuggingFace fallback squeezed the same request into the same
 * 2048-token budget.
 *
 * These tests pin the fix: a budget-exhausted completion is RETRIED ONCE with a
 * doubled budget, an empty completion (the same truncation without
 * `response_format`) is retried too, any other failure is NOT retried, and the
 * final rejection names the budget instead of hiding behind a TypeError.
 *
 * node:https is stubbed, so no network access is needed. These modules depend
 * only on node:https and ./tokenBudget, so the firebase-admin shim is not
 * required here.
 *
 * Run:  node --test test/ai_provider_budget_retry.test.js   (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");
const https = require("https");

const {
  JSON_MAX_TOKENS,
  MAX_ESCALATED_TOKENS,
  escalateMaxTokens,
} = require("../ai/tokenBudget");
const {callGroqAPI} = require("../ai/groqProvider");
const {callHuggingFaceAPI} = require("../ai/huggingfaceProvider");

const GROQ_JSON_VALIDATE_FAILED =
  '{"error":{"message":"Failed to generate JSON. Please adjust your prompt. ' +
  'See \'failed_generation\' for more details.","type":"invalid_request_error",' +
  '"code":"json_validate_failed","failed_generation":"max completion tokens ' +
  'reached before generating a valid document"}}';

/** A Groq/HF 200 body wrapping [content] with an explicit finish_reason. */
function completion(content, finishReason = "stop") {
  return JSON.stringify({
    model: "openai/gpt-oss-20b",
    choices: [
      {message: {role: "assistant", content}, finish_reason: finishReason},
    ],
    usage: {total_tokens: 1234},
  });
}

/**
 * Replace https.request with a scripted responder.
 *
 * Each entry of [responses] answers one attempt; the last entry is reused if a
 * provider makes more attempts than were scripted, so an over-retry shows up as
 * extra entries in `calls`.
 *
 * @param {Array<{status: number, body: string}>} responses - One per attempt
 * @returns {{calls: object[], restore: function}}
 */
function stubHttps(responses) {
  const calls = [];
  const original = https.request;

  function makeResponse(spec) {
    const handlers = {data: [], end: []};
    const res = {
      statusCode: spec.status,
      on(event, handler) {
        if (handlers[event]) handlers[event].push(handler);
        return res;
      },
    };
    // Emit only after the provider has attached its listeners.
    setImmediate(() => {
      handlers.data.forEach((handler) => handler(spec.body));
      handlers.end.forEach((handler) => handler());
    });
    return res;
  }

  https.request = (options, callback) => {
    let rawBody = "";
    const req = {
      on() {
        return req;
      },
      setTimeout() {
        return req;
      },
      write(chunk) {
        rawBody += chunk;
      },
      destroy() {},
      end() {
        const index = calls.length;
        const spec = responses[Math.min(index, responses.length - 1)];
        calls.push(JSON.parse(rawBody));
        setImmediate(() => callback(makeResponse(spec)));
      },
    };
    return req;
  };

  return {
    calls,
    restore() {
      https.request = original;
    },
  };
}

const originalGroqKey = process.env.GROQ_API_KEY;
const originalHfKey = process.env.HUGGINGFACE_API_KEY;
process.env.GROQ_API_KEY = originalGroqKey || "test-groq-key";
process.env.HUGGINGFACE_API_KEY = originalHfKey || "test-hf-key";

test.after(() => {
  if (originalGroqKey === undefined) delete process.env.GROQ_API_KEY;
  else process.env.GROQ_API_KEY = originalGroqKey;
  if (originalHfKey === undefined) delete process.env.HUGGINGFACE_API_KEY;
  else process.env.HUGGINGFACE_API_KEY = originalHfKey;
});

// ═════════════════════════════════════════════════════════════════════════
// 1 — the escalation policy itself
// ═════════════════════════════════════════════════════════════════════════

test("tokenBudget: escalating doubles the budget up to the ceiling, then stops", () => {
  assert.equal(escalateMaxTokens(JSON_MAX_TOKENS), MAX_ESCALATED_TOKENS);
  assert.equal(escalateMaxTokens(MAX_ESCALATED_TOKENS), null,
      "no further escalation is possible at the ceiling");
  assert.equal(escalateMaxTokens(MAX_ESCALATED_TOKENS + 1000), null);
  assert.ok(MAX_ESCALATED_TOKENS > JSON_MAX_TOKENS);

  for (const invalid of [0, -5, 1.5, "4096", null, undefined, NaN]) {
    assert.equal(
        escalateMaxTokens(invalid),
        MAX_ESCALATED_TOKENS,
        `escalateMaxTokens(${String(invalid)}) must fall back to the JSON budget`,
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 2 — Groq retries exactly once when the budget was exhausted
// ═════════════════════════════════════════════════════════════════════════

test("groq: a json_validate_failed 400 is retried once with a bigger budget", async () => {
  const stub = stubHttps([
    {status: 400, body: GROQ_JSON_VALIDATE_FAILED},
    {status: 200, body: completion('{"atsScore":75}')},
  ]);
  try {
    const content = await callGroqAPI("system", "user", {jsonMode: true});

    assert.equal(content, '{"atsScore":75}');
    assert.equal(stub.calls.length, 2, "exactly one retry");
    assert.equal(stub.calls[0].max_tokens, JSON_MAX_TOKENS);
    assert.equal(stub.calls[1].max_tokens, MAX_ESCALATED_TOKENS,
        "the retry must use the escalated budget");
    assert.equal(stub.calls[0].response_format.type, "json_object");
  } finally {
    stub.restore();
  }
});

test("groq: an empty completion is retried once with a bigger budget", async () => {
  const stub = stubHttps([
    {status: 200, body: completion(null, "length")},
    {status: 200, body: completion('{"atsScore":60}')},
  ]);
  try {
    const content = await callGroqAPI("system", "user", {jsonMode: true});

    assert.equal(content, '{"atsScore":60}');
    assert.equal(stub.calls.length, 2);
    assert.equal(stub.calls[1].max_tokens, MAX_ESCALATED_TOKENS);
  } finally {
    stub.restore();
  }
});

test("groq: a non-budget failure is NOT retried", async () => {
  const stub = stubHttps([
    {status: 401, body: '{"error":{"message":"Invalid API Key"}}'},
    {status: 200, body: completion("should never be reached")},
  ]);
  try {
    await assert.rejects(
        () => callGroqAPI("system", "user", {jsonMode: true}),
        /status 401/,
    );
    assert.equal(stub.calls.length, 1, "an auth failure must not be retried");
  } finally {
    stub.restore();
  }
});

test("groq: still empty after the retry rejects with a message naming the budget", async () => {
  const stub = stubHttps([{status: 200, body: completion(null, "length")}]);
  try {
    await assert.rejects(
        () => callGroqAPI("system", "user", {jsonMode: true}),
        (error) => {
          assert.ok(!(error instanceof TypeError), "must not be a TypeError");
          assert.match(error.message, /no answer/);
          assert.match(error.message, new RegExp(String(MAX_ESCALATED_TOKENS)));
          return true;
        },
    );
    assert.equal(stub.calls.length, 2, "the retry happens — but only once");
  } finally {
    stub.restore();
  }
});

test("groq: a still-exhausted budget after the retry surfaces the provider error", async () => {
  const stub = stubHttps([{status: 400, body: GROQ_JSON_VALIDATE_FAILED}]);
  try {
    await assert.rejects(
        () => callGroqAPI("system", "user", {jsonMode: true}),
        /json_validate_failed/,
    );
    assert.equal(stub.calls.length, 2, "exactly one retry, never a loop");
    assert.equal(stub.calls[1].max_tokens, MAX_ESCALATED_TOKENS);
  } finally {
    stub.restore();
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 3 — HuggingFace retries a JSON document that was cut off
// ═════════════════════════════════════════════════════════════════════════

test("huggingface: a truncated JSON document is retried once with a bigger budget", async () => {
  const stub = stubHttps([
    {status: 200, body: completion('{"atsScore":75,"stren', "length")},
    {status: 200, body: completion('{"atsScore":75}', "stop")},
  ]);
  try {
    const content = await callHuggingFaceAPI("system", "user", {jsonMode: true});

    assert.equal(content, '{"atsScore":75}');
    assert.equal(stub.calls.length, 2);
    assert.equal(stub.calls[0].max_tokens, JSON_MAX_TOKENS);
    assert.equal(stub.calls[1].max_tokens, MAX_ESCALATED_TOKENS);
  } finally {
    stub.restore();
  }
});

test("huggingface: a truncated PLAIN-TEXT reply is returned as-is (no retry)", async () => {
  const stub = stubHttps([
    {status: 200, body: completion("a partial chat answer", "length")},
  ]);
  try {
    const content = await callHuggingFaceAPI("system", "user", {jsonMode: false});
    assert.equal(content, "a partial chat answer");
    assert.equal(stub.calls.length, 1,
        "text mode tolerates a truncated answer; a retry would only add latency");
  } finally {
    stub.restore();
  }
});

test("huggingface: still cut off after the retry rejects with a clear message", async () => {
  const stub = stubHttps([
    {status: 200, body: completion('{"atsScore":75,"stren', "length")},
  ]);
  try {
    await assert.rejects(
        () => callHuggingFaceAPI("system", "user", {jsonMode: true}),
        (error) => {
          assert.ok(!(error instanceof TypeError), "must not be a TypeError");
          assert.match(error.message, /no usable answer/);
          assert.match(error.message, new RegExp(String(MAX_ESCALATED_TOKENS)));
          return true;
        },
    );
    assert.equal(stub.calls.length, 2);
  } finally {
    stub.restore();
  }
});

test("huggingface: an explicit maxTokens override is respected and escalated from", async () => {
  const stub = stubHttps([
    {status: 200, body: completion(null, "length")},
    {status: 200, body: completion("ok")},
  ]);
  try {
    const content = await callHuggingFaceAPI(
        "system", "user", {jsonMode: true, maxTokens: 3000},
    );
    assert.equal(content, "ok");
    assert.equal(stub.calls[0].max_tokens, 3000);
    assert.equal(stub.calls[1].max_tokens, 6000,
        "the retry doubles the caller's budget, not the module default");
  } finally {
    stub.restore();
  }
});
