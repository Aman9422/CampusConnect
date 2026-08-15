/**
 * CampusConnect v6.95 - HuggingFace Inference Providers
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
 */

const https = require("https");

/** HuggingFace Inference Providers - OpenAI-compatible endpoint */
const HF_API_URL = "https://router.huggingface.co/v1/chat/completions";

/**
 * Model to use via HuggingFace Inference Providers.
 * v8.8: migrated from meta-llama/Llama-3.1-8B-Instruct to openai/gpt-oss-20b.
 * Overridable via HF_MODEL for future migrations without a code deploy.
 */
const HF_MODEL = process.env.HF_MODEL || "openai/gpt-oss-20b";

/** Maximum tokens for the response */
const MAX_TOKENS = 2048;

/** Temperature for controlled output */
const TEMPERATURE = 0.3;

/**
 * Call the HuggingFace Inference Providers API with a system prompt and user prompt.
 *
 * Uses the OpenAI-compatible chat completions format via router.huggingface.co.
 * HuggingFace automatically selects the fastest available provider.
 *
 * @param {string} systemPrompt - System-level instructions
 * @param {string} userPrompt - User message with resume content
 * @param {object} [options] - Optional settings
 * @param {boolean} [options.jsonMode=true] - Whether to request JSON output
 * @returns {Promise<string>} Raw response text from the model
 * @throws {Error} If API call fails or key is missing
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

  const body = {
    model: HF_MODEL,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    max_tokens: MAX_TOKENS,
    temperature: TEMPERATURE,
    stream: false,
  };

  // v8.8: the router supports OpenAI-style structured outputs
  // (response_format) for gpt-oss models — mirror the Groq JSON mode so the
  // fallback produces equally reliable JSON for resume-review/analysis.
  if (useJsonMode) {
    body.response_format = { type: "json_object" };
  }

  const requestBody = JSON.stringify(body);

  console.log(
    `HuggingFace: Calling ${HF_MODEL} via Inference Providers (max_tokens: ${MAX_TOKENS})`
  );

  return new Promise((resolve, reject) => {
    const url = new URL(HF_API_URL);

    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        "Content-Length": Buffer.byteLength(requestBody),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        try {
          if (res.statusCode === 503) {
            // Provider temporarily unavailable
            reject(
              new Error(
                "HuggingFace inference provider temporarily unavailable. Please retry."
              )
            );
            return;
          }

          if (res.statusCode === 429) {
            reject(
              new Error(
                "HuggingFace rate limit reached. Please wait and retry."
              )
            );
            return;
          }

          if (res.statusCode !== 200) {
            console.error(`HuggingFace API error (${res.statusCode}):`, data);
            reject(
              new Error(
                `HuggingFace API returned status ${res.statusCode}: ${data.substring(0, 200)}`
              )
            );
            return;
          }

          const parsed = JSON.parse(data);

          // OpenAI-compatible response format
          let content = "";
          if (
            parsed.choices &&
            parsed.choices[0] &&
            parsed.choices[0].message
          ) {
            content = parsed.choices[0].message.content || "";
          } else {
            reject(
              new Error(
                "HuggingFace API returned unexpected response structure"
              )
            );
            return;
          }

          console.log(
            `HuggingFace: Response received (${content.length} chars)`
          );

          resolve(content);
        } catch (parseError) {
          reject(
            new Error(
              `Failed to parse HuggingFace response: ${parseError.message}`
            )
          );
        }
      });
    });

    req.on("error", (error) => {
      console.error("HuggingFace API request error:", error);
      reject(new Error(`HuggingFace API request failed: ${error.message}`));
    });

    // 60-second timeout (provider routing may take time)
    req.setTimeout(60000, () => {
      req.destroy();
      reject(new Error("HuggingFace API request timed out (60s)"));
    });

    req.write(requestBody);
    req.end();
  });
}

module.exports = {
  callHuggingFaceAPI,
};
