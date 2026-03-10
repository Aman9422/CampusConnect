/**
 * CampusConnect v6.95 - Groq AI Provider
 *
 * Calls the Groq API (https://api.groq.com) for fast LLM inference.
 * Groq runs open-source models (LLaMA, Mixtral) on custom LPU hardware.
 *
 * Environment:
 *   GROQ_API_KEY - Required API key from https://console.groq.com
 *
 * Model: llama-3.1-8b-instant (fast, free-tier friendly)
 */

const https = require("https");

/** Groq API endpoint */
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions";

/** Model to use - LLaMA 3.1 8B for speed + quality balance */
const GROQ_MODEL = "llama-3.1-8b-instant";

/** Maximum tokens for the response */
const MAX_TOKENS = 2048;

/** Temperature for deterministic output */
const TEMPERATURE = 0.3;

/**
 * Call the Groq API with a system prompt and user prompt.
 *
 * @param {string} systemPrompt - System-level instructions
 * @param {string} userPrompt - User message with resume content
 * @param {object} [options] - Optional settings
 * @param {boolean} [options.jsonMode=true] - Whether to request JSON output
 * @returns {Promise<string>} Raw response text from the model
 * @throws {Error} If API call fails or key is missing
 */
async function callGroqAPI(systemPrompt, userPrompt, options = {}) {
  const useJsonMode = options.jsonMode !== false; // default true
  const apiKey = process.env.GROQ_API_KEY;

  if (!apiKey) {
    throw new Error(
      "GROQ_API_KEY not configured. Set it via: " +
        "firebase functions:config:set ai.groq_api_key=YOUR_KEY " +
        'or set process.env.GROQ_API_KEY in .env file'
    );
  }

  const body = {
    model: GROQ_MODEL,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt },
    ],
    max_tokens: MAX_TOKENS,
    temperature: TEMPERATURE,
  };

  if (useJsonMode) {
    body.response_format = { type: "json_object" };
  }

  const requestBody = JSON.stringify(body);

  console.log(`Groq: Calling ${GROQ_MODEL} (max_tokens: ${MAX_TOKENS})`);

  return new Promise((resolve, reject) => {
    const url = new URL(GROQ_API_URL);

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
          if (res.statusCode !== 200) {
            console.error(`Groq API error (${res.statusCode}):`, data);
            reject(
              new Error(
                `Groq API returned status ${res.statusCode}: ${data.substring(0, 200)}`
              )
            );
            return;
          }

          const parsed = JSON.parse(data);

          if (
            !parsed.choices ||
            !parsed.choices[0] ||
            !parsed.choices[0].message
          ) {
            reject(new Error("Groq API returned unexpected response structure"));
            return;
          }

          const content = parsed.choices[0].message.content;
          console.log(
            `Groq: Response received (${content.length} chars, ` +
              `model: ${parsed.model}, ` +
              `tokens: ${parsed.usage?.total_tokens || "unknown"})`
          );

          resolve(content);
        } catch (parseError) {
          reject(new Error(`Failed to parse Groq response: ${parseError.message}`));
        }
      });
    });

    req.on("error", (error) => {
      console.error("Groq API request error:", error);
      reject(new Error(`Groq API request failed: ${error.message}`));
    });

    // 30-second timeout
    req.setTimeout(30000, () => {
      req.destroy();
      reject(new Error("Groq API request timed out (30s)"));
    });

    req.write(requestBody);
    req.end();
  });
}

module.exports = {
  callGroqAPI,
  GROQ_MODEL,
};
