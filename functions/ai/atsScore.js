"use strict";

/**
 * CampusConnect v9.3 — deterministic ATS scoring.
 *
 * WHY THIS MODULE EXISTS
 * ----------------------
 * The ATS score used to be whatever the LLM wrote into the `atsScore` field of
 * its JSON reply. Measured against the live provider (`openai/gpt-oss-20b`) the
 * same resume returned **60, then 55, then 55** on three consecutive calls, and
 * four otherwise-different student resumes landed inside a 55–68 band. Re-running
 * the same review therefore moved the number, and a genuinely improved resume
 * could not be told apart from an unchanged one — which is exactly the "it always
 * says 68 no matter what I upload" report.
 *
 * A number a student is asked to improve has to be REPRODUCIBLE and SENSITIVE to
 * the document. So the score is now computed here, in pure JavaScript, from
 * measurable properties of the resume text, and the model is used only for the
 * qualitative half (strengths, missing keywords, bullet rewrites, advice).
 *
 * The rubric is 100 points across seven categories:
 *
 *   contact & links ............ 10   (email 4, phone 2, profile link 4)
 *   core section coverage ...... 24   (summary 4, skills 5, projects 5,
 *                                      experience 6, education 4)
 *   quantified impact .......... 18   (achievement bullets carry numbers)
 *   action verbs ............... 12   (bullets open with a strong verb)
 *   bullet quality ............. 10   (count, length, verb variety)
 *   role keyword alignment ..... 18   (resume vs. the target role)
 *   length & parse-ability ...... 8   (words, line structure, dated history)
 *
 * Guarantees:
 *   - pure and deterministic: the same `(resumeText, targetRole)` always
 *     produces the same score, on the server and in tests;
 *   - sensitive: adding a number, a section or a role keyword never lowers it;
 *   - total-preserving: the category points sum to exactly the returned score.
 */

/** The maximum achievable score. */
const MAX_SCORE = 100;

/**
 * Category point budgets. Exported so the prompt builder and the tests agree with
 * the scorer instead of hard-coding the numbers twice.
 */
const CATEGORY_POINTS = {
  contact: 10,
  sections: 24,
  impact: 18,
  verbs: 12,
  bullets: 10,
  keywords: 18,
  format: 8,
};

/** Section aliases, longest first so "work experience" wins over "experience". */
const SECTION_ALIASES = {
  summary: [
    "professional summary", "career objective", "career summary", "summary",
    "objective", "profile", "about me", "about",
  ],
  skills: [
    "technical skills", "core competencies", "technologies used", "tech stack",
    "skill set", "skills", "technologies",
  ],
  projects: [
    "academic projects", "personal projects", "key projects", "projects",
    "project",
  ],
  experience: [
    "professional experience", "work experience", "employment history",
    "work history", "experience", "internships", "internship", "employment",
  ],
  education: [
    "educational qualifications", "academic background", "qualifications",
    "education", "academics",
  ],
};

/** Per-section weight inside the 24-point coverage category. */
const SECTION_POINTS = {
  summary: 4,
  skills: 5,
  projects: 5,
  experience: 6,
  education: 4,
};

/** Strong openers for an achievement bullet. */
const ACTION_VERBS = new Set([
  "accelerated", "achieved", "added", "administered", "adopted", "advanced",
  "analyzed", "analysed", "architected", "assembled", "assessed", "automated",
  "benchmarked", "built", "centralized", "centralised", "championed", "coached",
  "collaborated", "completed", "configured", "consolidated", "constructed",
  "contributed", "converted", "coordinated", "created", "cut", "debugged",
  "defined", "delivered", "demonstrated", "deployed", "designed", "detected",
  "developed", "devised", "diagnosed", "documented", "doubled", "drove",
  "earned", "eliminated", "enabled", "engineered", "enhanced", "ensured",
  "established", "evaluated", "executed", "expanded", "expedited", "facilitated",
  "founded", "generated", "grew", "guided", "handled", "headed", "identified",
  "implemented", "improved", "increased", "influenced", "initiated", "innovated",
  "inspected", "installed", "integrated", "introduced", "investigated", "launched",
  "led", "leveraged", "maintained", "managed", "mapped", "measured", "mentored",
  "migrated", "minimized", "minimised", "modelled", "modeled", "monitored",
  "negotiated", "onboarded", "operated", "optimized", "optimised", "orchestrated",
  "organized", "organised", "overhauled", "owned", "partnered", "performed",
  "pioneered", "planned", "prepared", "presented", "prioritized", "processed",
  "produced", "programmed", "proposed", "prototyped", "published", "rebuilt",
  "reduced", "refactored", "released", "remedied", "reorganised", "reorganized",
  "researched", "resolved", "restructured", "revamped", "reviewed", "rolled",
  "scaled", "secured", "served", "shipped", "simplified", "solved",
  "spearheaded", "standardized", "standardised", "steered", "streamlined",
  "strengthened", "structured", "supervised", "supported", "surpassed",
  "sustained", "synchronized", "tested", "tracked", "trained", "transformed",
  "translated", "tuned", "unified", "upgraded", "validated", "verified", "wrote",
]);

/**
 * Role tokens → the skills a reviewer would expect to see for that role.
 *
 * Keys are lower-case role tokens (matched as substrings of the target role) and
 * the longest matching token wins, so "full stack" beats "stack" and
 * "data scientist" beats "data".
 */
const ROLE_KEYWORD_MAP = {
  "full stack": ["javascript", "react", "node", "sql", "rest", "api", "git", "html", "css", "docker"],
  "frontend": ["javascript", "react", "html", "css", "typescript", "ui", "responsive", "redux", "git", "api"],
  "front end": ["javascript", "react", "html", "css", "typescript", "ui", "responsive", "redux", "git", "api"],
  "backend": ["api", "rest", "sql", "database", "server", "microservices", "docker", "git", "java", "python"],
  "back end": ["api", "rest", "sql", "database", "server", "microservices", "docker", "git", "java", "python"],
  "android": ["kotlin", "java", "android", "gradle", "retrofit", "ui", "git", "api", "firebase", "mvvm"],
  "ios": ["swift", "ios", "xcode", "uikit", "swiftui", "git", "api", "firebase", "ui", "objective-c"],
  "data scientist": ["python", "machine learning", "pandas", "numpy", "statistics", "sql", "model", "scikit", "visualization", "jupyter"],
  "data analyst": ["sql", "excel", "tableau", "power bi", "python", "dashboard", "reporting", "statistics", "visualization", "etl"],
  "machine learning": ["python", "pytorch", "tensorflow", "model", "training", "numpy", "pandas", "nlp", "scikit", "deep learning"],
  "devops": ["docker", "kubernetes", "ci/cd", "aws", "terraform", "linux", "jenkins", "pipeline", "monitoring", "bash"],
  "cloud": ["aws", "azure", "gcp", "docker", "kubernetes", "terraform", "linux", "networking", "iam", "monitoring"],
  "qa": ["testing", "selenium", "automation", "test cases", "junit", "cypress", "pytest", "bug", "regression", "postman"],
  "test engineer": ["testing", "selenium", "automation", "test cases", "junit", "cypress", "pytest", "bug", "regression", "postman"],
  "business analyst": ["sql", "excel", "requirements", "stakeholder", "documentation", "process", "reporting", "tableau", "agile", "kpi"],
  "product manager": ["roadmap", "stakeholder", "requirements", "agile", "prioritization", "metrics", "user research", "backlog", "strategy", "analytics"],
  "mechanical": ["solidworks", "autocad", "cad", "ansys", "manufacturing", "thermal", "design", "gd&t", "cnc", "catia"],
  "civil": ["autocad", "staad", "estimation", "surveying", "structural", "concrete", "site", "quantity", "revit", "project"],
  "electrical": ["matlab", "circuit", "power", "plc", "simulink", "embedded", "control", "wiring", "instrumentation", "autocad"],
  "embedded": ["c", "c++", "microcontroller", "i2c", "spi", "uart", "rtos", "arm", "firmware", "debugging"],
  "cyber": ["networking", "linux", "security", "penetration", "vulnerability", "firewall", "siem", "cryptography", "python", "owasp"],
  "security": ["networking", "linux", "security", "penetration", "vulnerability", "firewall", "siem", "cryptography", "python", "owasp"],
  "human resources": ["recruitment", "onboarding", "payroll", "employee", "hrms", "interview", "policy", "engagement", "attrition", "training"],
  "marketing": ["seo", "campaign", "social media", "analytics", "content", "brand", "google analytics", "email", "ads", "crm"],
  "finance": ["accounting", "excel", "financial", "budget", "audit", "tally", "taxation", "reconciliation", "forecasting", "erp"],
  "software": ["java", "python", "javascript", "sql", "git", "api", "testing", "oop", "data structures", "algorithms"],
  "developer": ["java", "python", "javascript", "sql", "git", "api", "testing", "oop", "data structures", "algorithms"],
  "engineer": ["java", "python", "javascript", "sql", "git", "api", "testing", "oop", "data structures", "algorithms"],
};

/** Role words that carry no signal on their own. */
const ROLE_STOPWORDS = new Set([
  "senior", "junior", "lead", "staff", "principal", "associate", "entry",
  "level", "general", "intern", "internship", "fresher", "student", "the",
  "and", "or", "a", "an", "of", "for", "role", "position", "job", "any",
]);

/** Recognised technology vocabulary, for role-free "technical density". */
const TECH_TERMS = [
  "java", "python", "javascript", "typescript", "c++", "c#", "go", "kotlin",
  "swift", "php", "ruby", "scala", "rust", "sql", "mysql", "postgresql",
  "mongodb", "sqlite", "oracle", "firebase", "redis", "react", "angular",
  "vue", "node", "express", "spring", "django", "flask", "laravel",
  "flutter", "dart", "android", "ios", "html", "css", "tailwind", "bootstrap",
  "redux", "graphql", "rest", "api", "grpc", "microservices", "docker",
  "kubernetes", "terraform", "jenkins", "github actions", "ci/cd", "aws",
  "azure", "gcp", "linux", "bash", "git", "github", "jira", "agile", "scrum",
  "pandas", "numpy", "matplotlib", "seaborn", "scikit", "tensorflow",
  "pytorch", "keras", "opencv", "nlp", "machine learning", "deep learning",
  "tableau", "power bi", "excel", "statistics", "etl", "hadoop", "spark",
  "kafka", "selenium", "junit", "pytest", "cypress", "postman", "figma",
  "solidworks", "autocad", "matlab", "ansys", "simulink", "plc", "verilog",
  "vhdl", "embedded", "rtos", "iot", "arduino", "raspberry pi",
];

/** Word-count bands for the length category (first match wins). */
const WORD_BANDS = [
  {min: 250, max: 900, points: 4},
  {min: 150, max: 1200, points: 3},
  {min: 80, max: 1600, points: 1},
];

/** Leading bullet glyphs / list markers. */
const BULLET_PREFIX = /^\s*(?:[-*\u2022\u25AA\u25E6\u2023\u00B7]|\d{1,2}[.)])\s+/;

/** Characters stripped when a line is tested as a section heading. */
const HEADING_TRIM = /^[\s#>*\-|\u2022\u25AA\u25E6\u2023]+|[\s:|\-*>#]+$/g;

/**
 * Lower-case and collapse whitespace, for matching only. The original text is
 * never modified by the scorer.
 *
 * @param {string} text
 * @returns {string}
 */
function normalize(text) {
  return String(text || "")
      .toLowerCase()
      .replace(/\s+/g, " ")
      .trim();
}

/**
 * Split into non-empty trimmed lines.
 *
 * @param {string} text
 * @returns {string[]}
 */
function splitLines(text) {
  return String(text || "")
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
}

/**
 * Words in a string, splitting on anything that is not a letter/digit/#/+/.
 *
 * @param {string} text
 * @returns {string[]}
 */
function words(text) {
  return String(text || "")
      .toLowerCase()
      .split(/[^a-z0-9#+]+/)
      .filter((word) => word.length > 0);
}

/**
 * Shortest alias that may match as a PREFIX rather than an exact heading.
 *
 * Short, generic aliases ("about", "skills", "project") are exact-match only:
 * otherwise "About the project we built" would be read as a Summary heading and
 * "skills are many things" as a Skills heading.
 */
const PREFIX_MATCH_MIN_ALIAS = 8;

/**
 * True when a line looks like the heading of one of [aliases].
 *
 * Resume headings are overwhelmingly upper- or title-case ("OBJECTIVE",
 * "Technical Skills"), so the line is lower-cased before comparison — the
 * aliases are lower-case. A heading is a line that, once decoration is
 * stripped, EQUALS an alias, or starts with a long alias followed by a short
 * decorative tail ("TECHNICAL SKILLS AND TOOLS").
 *
 * @param {string} line
 * @param {string[]} aliases - Longest first
 * @returns {boolean}
 */
function isHeadingLine(line, aliases) {
  const cleaned = String(line || "")
      .replace(HEADING_TRIM, "")
      .trim()
      .toLowerCase();
  if (cleaned.length === 0 || cleaned.length > 60) return false;

  for (const alias of aliases) {
    if (cleaned === alias) return true;
    if (alias.length < PREFIX_MATCH_MIN_ALIAS) continue;
    if (!cleaned.startsWith(alias)) continue;
    const tail = cleaned.slice(alias.length);
    // A tail that starts with a letter is a longer word ("skillsandmore"),
    // not a heading tail.
    if (tail.length > 0 && tail.length <= 24 && !/^[a-z]/.test(tail)) {
      return true;
    }
  }
  return false;
}

/**
 * True when the resume carries a section for [key].
 *
 * Headings are the primary signal. A resume that arrives as one unbroken blob
 * (no line structure) falls back to an "alias followed by a colon" search, so a
 * single-paragraph resume is not scored as if every section were missing.
 *
 * @param {string[]} lines
 * @param {string} key - A SECTION_ALIASES key
 * @returns {boolean}
 */
function hasSection(lines, key) {
  const aliases = SECTION_ALIASES[key] || [];

  for (const line of lines) {
    if (isHeadingLine(line, aliases)) return true;
  }

  if (lines.length <= 2) {
    const blob = normalize(lines.join(" "));
    for (const alias of aliases) {
      if (blob.includes(`${alias}:`)) return true;
    }
  }
  return false;
}

/**
 * Bullet lines of the resume (leading `-`, `*`, `•` or `1.` / `1)` markers).
 *
 * @param {string[]} lines
 * @returns {{text: string, words: string[]}[]}
 */
function extractBullets(lines) {
  const bullets = [];
  for (const line of lines) {
    if (!BULLET_PREFIX.test(line)) continue;
    const text = line.replace(BULLET_PREFIX, "").trim();
    if (text.length === 0) continue;
    bullets.push({text, words: words(text)});
  }
  return bullets;
}

/**
 * Contact-block signals.
 *
 * @param {string} text
 * @returns {{email: boolean, phone: boolean, link: boolean}}
 */
function detectContact(text) {
  const raw = String(text || "");
  return {
    email: /[A-Za-z0-9._%+'-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/.test(raw),
    phone: /(?:\+?\d[\d\s().-]{7,}\d)/.test(raw),
    link: /(linkedin\.com|github\.com|gitlab\.com|bitbucket\.org|behance\.net|dribbble\.com|leetcode\.com|hackerrank\.com|kaggle\.com|medium\.com|https?:\/\/)/i
        .test(raw),
  };
}

/**
 * The expected-skill list for a target role, or [] when the role is too generic
 * to measure alignment against.
 *
 * The longest matching key wins so "data scientist" beats "data" and
 * "full stack" beats "stack".
 *
 * @param {string} targetRole
 * @returns {string[]}
 */
function roleKeywords(targetRole) {
  const role = normalize(targetRole);
  if (role.length === 0) return [];

  const meaningful = words(role).filter((word) => !ROLE_STOPWORDS.has(word));
  if (meaningful.length === 0) return [];

  let best = null;
  for (const key of Object.keys(ROLE_KEYWORD_MAP)) {
    if (role.includes(key) && (best === null || key.length > best.length)) {
      best = key;
    }
  }
  return best ? ROLE_KEYWORD_MAP[best] : [];
}

/**
 * Which of [keywords] appear in the resume. `sql` matches inside `mysql`, etc.
 *
 * @param {string} haystack - Pre-normalized resume text
 * @param {string[]} keywords
 * @returns {string[]}
 */
function matchedKeywords(haystack, keywords) {
  return keywords.filter((keyword) => haystack.includes(keyword));
}

/**
 * How many distinct recognised technologies the resume mentions.
 *
 * @param {string} haystack - Pre-normalized resume text
 * @returns {number}
 */
function techTermCount(haystack) {
  let count = 0;
  for (const term of TECH_TERMS) {
    if (haystack.includes(term)) count++;
  }
  return count;
}

// ── category scorers ────────────────────────────────────────────────────────

/** Quantified-impact bands on the share of bullets that carry a number. */
const IMPACT_BANDS = [
  {min: 0.5, points: 18},
  {min: 0.3, points: 15},
  {min: 0.15, points: 10},
  {min: 0.05, points: 5},
];

/** Action-verb bands on the share of bullets that OPEN with a strong verb. */
const VERB_BANDS = [
  {min: 0.6, points: 12},
  {min: 0.45, points: 9},
  {min: 0.3, points: 6},
  {min: 0.15, points: 3},
];

/** Keyword-coverage bands for a role that has a known keyword set. */
const KEYWORD_BANDS = [
  {min: 0.7, points: 18},
  {min: 0.5, points: 15},
  {min: 0.35, points: 11},
  {min: 0.2, points: 7},
  {min: 0.1, points: 3},
];

/** Technology-density bands used when the target role has no keyword set. */
const DENSITY_BANDS = [
  {min: 12, points: 14},
  {min: 8, points: 11},
  {min: 5, points: 8},
  {min: 3, points: 5},
  {min: 1, points: 2},
];

/**
 * Pick the points of the first band whose threshold [value] meets.
 *
 * @param {number} value
 * @param {{min: number, points: number}[]} bands - Descending by `min`
 * @returns {number}
 */
function bandPoints(value, bands) {
  for (const band of bands) {
    if (value >= band.min) return band.points;
  }
  return 0;
}

/**
 * @param {{email: boolean, phone: boolean, link: boolean}} contact
 * @returns {object} Category result
 */
function scoreContact(contact) {
  let points = 0;
  const found = [];
  if (contact.email) {
    points += 4;
    found.push("email");
  }
  if (contact.phone) {
    points += 2;
    found.push("phone");
  }
  if (contact.link) {
    points += 4;
    found.push("profile link");
  }
  return {
    id: "contact",
    label: "Contact & links",
    points,
    max: CATEGORY_POINTS.contact,
    detail: found.length > 0 ?
      `found ${found.join(", ")}` :
      "no email, phone or profile link found",
  };
}

/**
 * @param {string[]} lines
 * @returns {object} Category result
 */
function scoreSections(lines) {
  let points = 0;
  const found = [];
  const missing = [];
  for (const key of Object.keys(SECTION_POINTS)) {
    if (hasSection(lines, key)) {
      points += SECTION_POINTS[key];
      found.push(key);
    } else {
      missing.push(key);
    }
  }
  return {
    id: "sections",
    label: "Section coverage",
    points,
    max: CATEGORY_POINTS.sections,
    detail: missing.length === 0 ?
      "all five core sections present" :
      `missing: ${missing.join(", ")}`,
  };
}

/**
 * Quantified impact: does the resume state numbers, and does it state them in
 * its achievement bullets?
 *
 * @param {{text: string}[]} bullets
 * @param {number} numericLines - Non-empty lines that contain a digit
 * @returns {object} Category result
 */
function scoreImpact(bullets, numericLines) {
  const max = CATEGORY_POINTS.impact;
  const total = bullets.length;
  const quantified = bullets.filter((bullet) => /\d/.test(bullet.text)).length;
  const ratio = total > 0 ? quantified / total : 0;

  let points = bandPoints(ratio, IMPACT_BANDS);

  // Too few bullets to establish a habit of quantifying.
  if (total < 3 && points > 8) points = 8;

  // Numbers that never made it into a bullet still count for something.
  if (points === 0 && numericLines >= 4) points = 3;

  return {
    id: "impact",
    label: "Quantified impact",
    points,
    max,
    detail: `${quantified}/${total} bullets contain a number ` +
      `(${numericLines} numeric lines overall)`,
  };
}

/**
 * Action verbs: do bullets OPEN with a strong verb rather than a noun phrase?
 *
 * @param {{words: string[]}[]} bullets
 * @returns {object} Category result
 */
function scoreVerbs(bullets) {
  const max = CATEGORY_POINTS.verbs;
  const total = bullets.length;
  if (total === 0) {
    return {
      id: "verbs",
      label: "Action verbs",
      points: 0,
      max,
      detail: "no bullet points to evaluate",
    };
  }

  const strong = bullets.filter((bullet) =>
    bullet.words.length > 0 && ACTION_VERBS.has(bullet.words[0]),
  ).length;
  const ratio = strong / total;

  let points = bandPoints(ratio, VERB_BANDS);
  if (points === 0 && strong > 0) points = 1;
  if (total < 3 && points > 5) points = 5;

  return {
    id: "verbs",
    label: "Action verbs",
    points,
    max,
    detail: `${strong}/${total} bullets open with a strong action verb`,
  };
}

/**
 * Bullet quality: enough bullets, readable length, varied openers.
 *
 * @param {{words: string[], text: string}[]} bullets
 * @returns {object} Category result
 */
function scoreBullets(bullets) {
  const max = CATEGORY_POINTS.bullets;
  const total = bullets.length;

  let points = 0;
  const notes = [];

  if (total >= 6) points += 5;
  else if (total >= 3) points += 3;
  else if (total >= 1) points += 1;
  notes.push(`${total} bullet${total === 1 ? "" : "s"}`);

  if (total > 0) {
    const lengths = bullets.map((bullet) => bullet.words.length);
    const average = lengths.reduce((sum, n) => sum + n, 0) / total;
    if (average >= 8 && average <= 28) points += 3;
    else if (average >= 5 && average <= 40) points += 2;
    notes.push(`avg ${average.toFixed(1)} words/bullet`);
  }

  const openers = new Set(
      bullets.map((bullet) => bullet.words[0]).filter(Boolean),
  );
  if (openers.size >= 3) points += 2;
  else if (openers.size >= 1) points += 1;

  return {
    id: "bullets",
    label: "Bullet quality",
    points: Math.min(points, max),
    max,
    detail: notes.join(", "),
  };
}

/**
 * Role keyword alignment. Falls back to raw technology density (capped at 14 of
 * 18) when the target role is too generic to have a keyword set — a resume
 * cannot be penalised for keywords nobody could name.
 *
 * @param {string} haystack - Pre-normalized resume text
 * @param {string} targetRole
 * @returns {object} Category result
 */
function scoreKeywords(haystack, targetRole) {
  const max = CATEGORY_POINTS.keywords;
  const keywords = roleKeywords(targetRole);

  if (keywords.length > 0) {
    const matches = matchedKeywords(haystack, keywords);
    const coverage = matches.length / keywords.length;
    return {
      id: "keywords",
      label: "Role keyword alignment",
      points: bandPoints(coverage, KEYWORD_BANDS),
      max,
      detail: `${matches.length}/${keywords.length} expected keywords present ` +
        `for "${String(targetRole || "").trim()}"`,
    };
  }

  const terms = techTermCount(haystack);
  return {
    id: "keywords",
    label: "Role keyword alignment",
    points: bandPoints(terms, DENSITY_BANDS),
    max,
    detail: `no keyword set for "${String(targetRole || "").trim() || "unspecified role"}"; ` +
      `${terms} recognised technologies found`,
  };
}

/**
 * Length and parse-ability: a sensible word count, real line structure and a
 * dated history.
 *
 * @param {string} text
 * @param {string[]} lines
 * @returns {object} Category result
 */
function scoreFormat(text, lines) {
  const max = CATEGORY_POINTS.format;
  const count = words(text).length;

  let points = 0;
  for (const band of WORD_BANDS) {
    if (count >= band.min && count <= band.max) {
      points += band.points;
      break;
    }
  }

  if (lines.length >= 5) points += 2;
  if (/\b(?:19|20)\d{2}\b/.test(String(text || ""))) points += 2;

  return {
    id: "format",
    label: "Length & structure",
    points: Math.min(points, max),
    max,
    detail: `${count} words across ${lines.length} lines`,
  };
}

/**
 * Score a resume. The single entry point — pure and deterministic.
 *
 * @param {string} resumeText - Plain-text resume
 * @param {string} [targetRole] - Target role, for keyword alignment
 * @returns {{score: number, categories: object[]}} `score` is 0-100 and always
 *   equals the sum of `categories[].points`
 */
function scoreResume(resumeText, targetRole) {
  const text = typeof resumeText === "string" ? resumeText : "";
  const lines = splitLines(text);
  const haystack = normalize(text);
  const bullets = extractBullets(lines);
  const numericLines = lines.filter((line) => /\d/.test(line)).length;

  const categories = [
    scoreContact(detectContact(text)),
    scoreSections(lines),
    scoreImpact(bullets, numericLines),
    scoreVerbs(bullets),
    scoreBullets(bullets),
    scoreKeywords(haystack, targetRole),
    scoreFormat(text, lines),
  ];

  const total = categories.reduce((sum, category) => sum + category.points, 0);
  return {
    score: Math.max(0, Math.min(MAX_SCORE, total)),
    categories,
  };
}

/**
 * Render a score result as the short text block embedded in the AI prompt, so
 * the model's qualitative advice agrees with the number the student is shown.
 *
 * @param {{score: number, categories: object[]}} result - From [scoreResume]
 * @returns {string}
 */
function describeScore(result) {
  const lines = result.categories.map((category) =>
    `- ${category.label}: ${category.points}/${category.max} (${category.detail})`,
  );
  return [
    `DETERMINISTIC ATS SCORE: ${result.score}/100`,
    "Category breakdown:",
    ...lines,
  ].join("\n");
}

module.exports = {
  MAX_SCORE,
  CATEGORY_POINTS,
  SECTION_ALIASES,
  SECTION_POINTS,
  ACTION_VERBS,
  ROLE_KEYWORD_MAP,
  TECH_TERMS,
  WORD_BANDS,
  IMPACT_BANDS,
  VERB_BANDS,
  KEYWORD_BANDS,
  DENSITY_BANDS,
  PREFIX_MATCH_MIN_ALIAS,
  normalize,
  splitLines,
  words,
  isHeadingLine,
  hasSection,
  extractBullets,
  detectContact,
  roleKeywords,
  matchedKeywords,
  techTermCount,
  bandPoints,
  scoreResume,
  describeScore,
};
