/**
 * CampusConnect v9.2.5 - Groq AI Provider
 *
 * Calls the Groq API (https://api.groq.com) for fast LLM inference.
 *
 * Environment:
 *   GROQ_API_KEY - Required API key from https://console.groq.com
 *   GROQ_MODEL   - Optional model override (default "openai/gpt-oss-20b")
 *
 * Model: openai/gpt-oss-20b (v8.8 primary — OpenAI GPT-OSS 20B, fast,
 * strong reasoning, 131k context, supports structured outputs)
 *
 * TRUNCATED COMPLETIONS (v9.2.5)
 * -----------------------------
 * `openai/gpt-oss-20b` is a REASONING model: its `max_tokens` budget covers the
 * reasoning trace AND the answer. The deployed logs (2026-09-29) show a resume
 * review sent with `max_tokens: 2048` answered by
 *
 *   400 {"error":{"code":"json_validate_failed",
 *        "failed_generation":"max completion tokens reached before generating
 *                          a valid document"}}
 *
 * The budget — not the prompt — was the problem. This module therefore:
 *   1. treats that specific 400 (and an empty completion, which is the same
 *      truncation without `response_format`) as a RETRYABLE budget failure,
 *   2. retries ONCE with a doubled budget (`escalateMaxTokens`),
 *   3. only then rejects, with a message that names the budget.
 */

const https = require("https");
const {resolveMaxTokens, escalateMaxTokens} = require("./tokenBudget");

/** Groq API endpoint */
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

/**
 * Model to use. v8.8: migrated from llama-3.1-8b-instant to
 * openai/gpt-oss-20b. Overridable via GROQ_MODEL for future migrations
 * without a code deploy.
 */
const GROQ_MODEL = process.env.GROQ_MODEL || "openai/gpt-oss-20b";

/** Temperature for deterministic output */
const TEMPERATURE = 0.3;

/** Per-attempt request timeout. */
const REQUEST_TIMEOUT_MS = 30000;

/** Groq's error code for "the model did not finish a valid JSON document". */
const JSON_VALIDATE_FAILED_CODE = "json_validate_failed";

/**
 * A non-200 answer from Groq, carrying the status and body so the caller can
 * decide whether the failure is worth retrying with a larger budget.
 */
class GroqApiError extends Error {
  /**
   * @param {string} message - Human-readable summary
   * @param {object} [info]
   * @param {number} [info.status] - HTTP status
   * @param {string} [info.body] - Raw response body
   */
  constructor(message, {status, body} = {}) {
    super(message);
    this.name = "GroqApiError";
    this.status = status;
    this.body = typeof body === "string" ? body : "";
  }
}

/**
 * True when Groq refused the answer because the completion budget ran out —
 * the reasoning trace consumed every token before the document was closed.
 *
 * @param {Error} error - A rejection from [requestCompletion]
 * @returns {boolean}
 */
function isBudgetExhaustedError(error) {
  if (!(error instanceof GroqApiError) || error.status !== 400) return false;
  return error.body.includes(JSON_VALIDATE_FAILED_CODE) ||
    /max completion tokens reached/i.test(error.body);
}

/**
 * The model's answer text, or "" when the response carries none.
 *
 * `message.content` is `null` for a reasoning model that spent its whole budget
 * on the reasoning trace; the previous `content.length` read threw a TypeError
 * on exactly that response and reported "Failed to parse Groq response", which
 * hid the real cause.
 *
 * @param {object} parsed - Decoded 200 response body
 * @returns {string}
 */
function completionText(parsed) {
  const content = parsed?.choices?.[0]?.message?.content;
  return typeof content === "string" ? content : "";
}

/**
 * Why the model stopped ("stop", "length", ...). `"length"` means truncated.
 *
 * @param {object} parsed - Decoded 200 response body
 * @returns {string} Finish reason, or "unknown"
 */
function completionFinishReason(parsed) {
  return parsed?.choices?.[0]?.finish_reason || "unknown";
}

/**
 * One HTTPS round trip to Groq.
 *
 * @param {string} requestBody - Serialized request body
 * @param {string} apiKey - Groq API key
 * @returns {Promise<object>} Decoded 200 response body
 * @throws {GroqApiError} On a non-200 answer
 * @throws {Error} On a transport failure, timeout or malformed body
 */
function requestCompletion(requestBody, apiKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(GROQ_API_URL);

    const requestOptions = {
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        "Content-Length": Buffer.byteLength(requestBody),
      },
    };

    const req = https.request(requestOptions, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        if (res.statusCode !== 200) {
          console.error(`Groq API error (${res.statusCode}):`, data);
          reject(
              new GroqApiError(
                  `Groq API returned status ${res.statusCode}: ` +
                  `${data.substring(0, 200)}`,
                  {status: res.statusCode, body: data}
              )
          );
          return;
        }

        try {
          const parsed = JSON.parse(data);
          if (!parsed.choices || !parsed.choices[0] ||
              !parsed.choices[0].message) {
            reject(new Error(
                "Groq API returned unexpected response structure"
            ));
            return;
          }
          resolve(parsed);
        } catch (parseError) {
          reject(new Error(
              `Failed to parse Groq response: ${parseError.message}`
          ));
        }
      });
    });

    req.on("error", (error) => {
      console.error("Groq API request error:", error);
      reject(new Error(`Groq API request failed: ${error.message}`));
    });

    req.setTimeout(REQUEST_TIMEOUT_MS, () => {
      req.destroy();
      reject(new Error("Groq API request timed out (30s)"));
    });

    req.write(requestBody);
    req.end();
  });
}

/**
 * Call the Groq API with a system prompt and user prompt.
 *
 * Retries ONCE with a doubled completion budget when the answer was cut off by
 * `max_tokens` (see the module header), then rejects.
 *
 * @param {string} systemPrompt - System-level instructions
 * @param {string} userPrompt - User message with resume content
 * @param {object} [options] - Optional settings
 * @param {boolean} [options.jsonMode=true] - Whether to request JSON output
 * @param {number} [options.maxTokens] - Explicit completion budget
 * @returns {Promise<string>} Raw response text from the model
 * @throws {Error} If the call fails, the key is missing, or the model still
 *   returns nothing after the retry
 */
async function callGroqAPI(systemPrompt, userPrompt, options = {}) {
  const useJsonMode = options.jsonMode !== false; // default true
  const apiKey = process.env.GROQ_API_KEY;

  if (!apiKey) {
    throw new Error(
        "GROQ_API_KEY not configured. Set it via: " +
        "firebase functions:config:set ai.groq_api_key=YOUR_KEY " +
        "or add GROQ_API_KEY to functions/.env"
    );
  }

  let maxTokens = resolveMaxTokens({...options, jsonMode: useJsonMode});

  for (let attempt = 0; ; attempt++) {
    const body = {
      model: GROQ_MODEL,
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      max_tokens: maxTokens,
      temperature: TEMPERATURE,
    };

    if (useJsonMode) {
      body.response_format = {type: "json_object"};
    }

    console.log(
        `Groq: Calling ${GROQ_MODEL} (max_tokens: ${maxTokens}` +
        `${attempt > 0 ? ", retry after truncation" : ""})`
    );

    let parsed;
    try {
      parsed = await requestCompletion(JSON.stringify(body), apiKey);
    } catch (error) {
      const escalated = attempt === 0 && isBudgetExhaustedError(error) ?
        escalateMaxTokens(maxTokens) :
        null;
      if (escalated) {
        console.warn(
            `Groq: the ${maxTokens}-token budget was exhausted before a valid ` +
            `document was produced; retrying with ${escalated} tokens.`
        );
        maxTokens = escalated;
        continue;
      }
      throw error;
    }

    const content = completionText(parsed);
    const finishReason = completionFinishReason(parsed);

    console.log(
        `Groq: Response received (${content.length} chars, ` +
        `model: ${parsed.model}, ` +
        `finish_reason: ${finishReason}, ` +
        `tokens: ${parsed.usage?.total_tokens || "unknown"})`
    );

    if (content.trim().length > 0) return content;

    // An empty completion from a reasoning model means the budget went to the
    // reasoning trace. Give the retry a chance before failing the request.
    const escalated = attempt === 0 ? escalateMaxTokens(maxTokens) : null;
    if (escalated) {
      console.warn(
          `Groq: empty completion (finish_reason: ${finishReason}); ` +
          `retrying with ${escalated} tokens.`
      );
      maxTokens = escalated;
      continue;
    }

    throw new Error(
        `Groq returned no answer (finish_reason: ${finishReason}). The model ` +
        `spent the whole ${maxTokens}-token completion budget without ` +
        `producing content.`
    );
  }
}

module.exports = {
  callGroqAPI,
  GROQ_MODEL,
  GroqApiError,
  isBudgetExhaustedError,
};
