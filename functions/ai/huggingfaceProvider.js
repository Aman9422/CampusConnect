/**
 * CampusConnect v9.2.5 - HuggingFace Inference Providers
 *
 * Uses HuggingFace's OpenAI-compatible Inference Providers API.
 * Routes through router.huggingface.co which proxies to partner providers
 * (Cerebras, SambaNova, Novita, Nscale, Featherless AI, etc.).
 *
 * Environment:
 *   HUGGINGFACE_API_KEY - Required fine-grained token from
 *     https://huggingface.co/settings/tokens
 *     (needs "Make calls to Inference Providers" permission)
 *   HF_MODEL           - Optional model override (default "openai/gpt-oss-20b")
 *
 * Model: openai/gpt-oss-20b (v8.8 fallback — same model as the Groq primary,
 * so provider failover is seamless: identical capabilities + output style).
 * - Supported on Inference Providers via the OpenAI-compatible router
 * - Supports structured outputs (response_format)
 *
 * TRUNCATED COMPLETIONS (v9.2.5)
 * -----------------------------
 * `openai/gpt-oss-20b` is a REASONING model: `max_tokens` covers the reasoning
 * trace AND the answer. This is the FALLBACK provider, and the deployed logs
 * show it carrying resume reviews that Groq rejected for exhausting its budget
 * (2026-09-29: "Groq API error (400) ... max completion tokens reached").
 *
 * Unlike Groq, the router does not validate `response_format: json_object`, so
 * a truncated answer arrives as a 200 with `finish_reason: "length"` and an
 * INCOMPLETE JSON document — which then fails `JSON.parse` further up. This
 * module therefore:
 *   1. reads `message.content` defensively (it is `null`, not `""`, for a
 *      reasoning model that spent the whole budget on its reasoning trace),
 *   2. retries ONCE with a doubled budget when the answer was empty or the
 *      JSON was cut off (`escalateMaxTokens`),
 *   3. only then rejects, with a message that names the budget.
 */

const https = require("https");
const {resolveMaxTokens, escalateMaxTokens} = require("./tokenBudget");

/** HuggingFace Inference Providers - OpenAI-compatible endpoint */
const HF_API_URL = "https://router.huggingface.co/v1/chat/completions";

/**
 * Model to use via HuggingFace Inference Providers.
 * v8.8: migrated from meta-llama/Llama-3.1-8B-Instruct to openai/gpt-oss-20b.
 * Overridable via HF_MODEL for future migrations without a code deploy.
 */
const HF_MODEL = process.env.HF_MODEL || "openai/gpt-oss-20b";

/** Temperature for controlled output */
const TEMPERATURE = 0.3;

/** Per-attempt request timeout (provider routing may take time). */
const REQUEST_TIMEOUT_MS = 60000;

/**
 * The model's answer text, or "" when the response carries none.
 *
 * @param {object} parsed - Decoded response body
 * @returns {string}
 */
function completionText(parsed) {
  const content = parsed?.choices?.[0]?.message?.content;
  return typeof content === "string" ? content : "";
}

/**
 * Why the model stopped ("stop", "length", ...). `"length"` means truncated.
 *
 * @param {object} parsed - Decoded response body
 * @returns {string} Finish reason, or "unknown"
 */
function completionFinishReason(parsed) {
  return parsed?.choices?.[0]?.finish_reason || "unknown";
}

/**
 * One HTTPS round trip to the HuggingFace router.
 *
 * @param {string} requestBody - Serialized request body
 * @param {string} apiKey - HuggingFace token
 * @returns {Promise<object>} Decoded 200 response body
 * @throws {Error} On any non-200 answer, transport failure or timeout
 */
function requestCompletion(requestBody, apiKey) {
  return new Promise((resolve, reject) => {
    const url = new URL(HF_API_URL);

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
        if (res.statusCode === 503) {
          reject(new Error(
              "HuggingFace inference provider temporarily unavailable. " +
              "Please retry."
          ));
          return;
        }

        if (res.statusCode === 429) {
          reject(new Error(
              "HuggingFace rate limit reached. Please wait and retry."
          ));
          return;
        }

        if (res.statusCode !== 200) {
          console.error(`HuggingFace API error (${res.statusCode}):`, data);
          reject(new Error(
              `HuggingFace API returned status ${res.statusCode}: ` +
              `${data.substring(0, 200)}`
          ));
          return;
        }

        try {
          const parsed = JSON.parse(data);
          if (!parsed.choices || !parsed.choices[0] ||
              !parsed.choices[0].message) {
            reject(new Error(
                "HuggingFace API returned unexpected response structure"
            ));
            return;
          }
          resolve(parsed);
        } catch (parseError) {
          reject(new Error(
              `Failed to parse HuggingFace response: ${parseError.message}`
          ));
        }
      });
    });

    req.on("error", (error) => {
      console.error("HuggingFace API request error:", error);
      reject(new Error(`HuggingFace API request failed: ${error.message}`));
    });

    req.setTimeout(REQUEST_TIMEOUT_MS, () => {
      req.destroy();
      reject(new Error("HuggingFace API request timed out (60s)"));
    });

    req.write(requestBody);
    req.end();
  });
}

/**
 * Call the HuggingFace Inference Providers API with a system prompt and user
 * prompt.
 *
 * Uses the OpenAI-compatible chat completions format via
 * router.huggingface.co. HuggingFace automatically selects the fastest
 * available provider.
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
 *   returns nothing usable after the retry
 */
async function callHuggingFaceAPI(systemPrompt, userPrompt, options = {}) {
  const useJsonMode = options.jsonMode !== false; // default true
  const apiKey = process.env.HUGGINGFACE_API_KEY;

  if (!apiKey) {
    throw new Error(
        "HUGGINGFACE_API_KEY not configured. " +
        "Create a fine-grained token at https://huggingface.co/settings/tokens " +
        'with "Make calls to Inference Providers" permission. ' +
        "Then set it in functions/.env as HUGGINGFACE_API_KEY=hf_xxx"
    );
  }

  let maxTokens = resolveMaxTokens({...options, jsonMode: useJsonMode});

  for (let attempt = 0; ; attempt++) {
    const body = {
      model: HF_MODEL,
      messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt},
      ],
      max_tokens: maxTokens,
      temperature: TEMPERATURE,
      stream: false,
    };

    // v8.8: the router supports OpenAI-style structured outputs
    // (response_format) for gpt-oss models — mirror the Groq JSON mode so the
    // fallback produces equally reliable JSON for resume-review/analysis.
    if (useJsonMode) {
      body.response_format = {type: "json_object"};
    }

    console.log(
        `HuggingFace: Calling ${HF_MODEL} via Inference Providers ` +
        `(max_tokens: ${maxTokens}` +
        `${attempt > 0 ? ", retry after truncation" : ""})`
    );

    const parsed = await requestCompletion(JSON.stringify(body), apiKey);

    const content = completionText(parsed);
    const finishReason = completionFinishReason(parsed);
    const truncated = finishReason === "length";

    console.log(
        `HuggingFace: Response received (${content.length} chars, ` +
        `finish_reason: ${finishReason})`
    );

    // A truncated JSON document is unusable: it will fail JSON.parse upstream.
    const unusable = content.trim().length === 0 ||
      (useJsonMode && truncated);

    if (!unusable) return content;

    const escalated = attempt === 0 ? escalateMaxTokens(maxTokens) : null;
    if (escalated) {
      console.warn(
          `HuggingFace: ${content.trim().length === 0 ?
            "empty completion" :
            "the JSON document was cut off"} ` +
          `(finish_reason: ${finishReason}); retrying with ${escalated} tokens.`
      );
      maxTokens = escalated;
      continue;
    }

    throw new Error(
        `HuggingFace returned no usable answer (finish_reason: ${finishReason}). ` +
        `The model spent the whole ${maxTokens}-token completion budget ` +
        `without producing a complete response.`
    );
  }
}

module.exports = {
  callHuggingFaceAPI,
};
