"use strict";

/**
 * CampusConnect v9.3 — the deterministic ATS scorer.
 *
 * WHY THIS SUITE EXISTS
 * ---------------------
 * The ATS score used to come from the LLM's JSON reply. Measured against the
 * live provider, ONE resume returned 60, then 55, then 55, and four different
 * student resumes sat inside a 55–68 band. A student re-running a review saw the
 * number move on its own, and an improved resume could not be distinguished from
 * an unchanged one — the "it always says 68 whatever I upload" report.
 *
 * These tests pin the properties the score now has to have:
 *   - DETERMINISTIC: same input, same score, always;
 *   - SENSITIVE: a better resume scores strictly higher, by a wide margin;
 *   - WELL-FORMED: categories sum to the score, budgets sum to 100, 0 ≤ score ≤ 100;
 *   - ROBUST: never throws on odd input (empty, non-string, malformed role).
 *
 * Pure module — no firebase-admin, no network.
 *
 * Run:  node --test test/ats_score.test.js   (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");

const {
  MAX_SCORE,
  CATEGORY_POINTS,
  SECTION_POINTS,
  SECTION_ALIASES,
  IMPACT_BANDS,
  isHeadingLine,
  hasSection,
  extractBullets,
  detectContact,
  roleKeywords,
  matchedKeywords,
  bandPoints,
  scoreResume,
  describeScore,
} = require("../ai/atsScore");

// ═════════════════════════════════════════════════════════════════════════
// Fixtures
// ═════════════════════════════════════════════════════════════════════════

/** A realistic, mediocre student resume — the common case. */
const TYPICAL_RESUME = `RAHUL VERMA
rahul.verma@gmail.com | +91 98765 43210 | Bengaluru

OBJECTIVE
To obtain a challenging position where I can use my skills and grow.

EDUCATION
B.E. Computer Science, VTU, 2021-2025, CGPA 7.8/10

SKILLS
C, C++, Java, HTML, CSS, JavaScript, MySQL, Git

PROJECTS
Library Management System
- Developed a web application to manage books using Java and MySQL.
- Implemented add, search and issue book features.

INTERNSHIP
Web Development Intern, TechNova Solutions, Jun 2024 - Aug 2024
- Worked on the company website and fixed bugs.`;

/** The same student, rewritten properly: quantified, linked, complete. */
const STRONG_RESUME = `RAHUL VERMA
rahul.verma@gmail.com | +91 98765 43210 | github.com/rahulverma | linkedin.com/in/rahulverma

SUMMARY
Final-year CSE student and backend developer. Shipped a Java/Spring service used by 1,200 students.

EDUCATION
B.E. Computer Science, VTU, 2021-2025, CGPA 8.6/10 (top 10% of 240)

EXPERIENCE
Backend Developer Intern, TechNova Solutions, Jun 2024 - Aug 2024
- Migrated the legacy PHP site to Spring Boot, cutting page load from 4.2s to 0.9s.
- Added Redis caching for the catalogue API, reducing database queries by 73%.

PROJECTS
Campus Library System (Java, Spring Boot, MySQL, Redis)
- Serves 1,200 active users; cut counter wait from 6 minutes to 40 seconds.
- Wrote 220 integration tests; maintained 91% line coverage in CI.
Result Portal (React, Node.js, PostgreSQL)
- Serves 3,000 students; p95 API latency 120ms under a 500-request load test.

SKILLS
Languages: Java, Python, SQL, JavaScript
Frameworks: Spring Boot, Node.js, React
Data/Infra: MySQL, PostgreSQL, Redis, Docker, Git, GitHub Actions, AWS EC2`;

/** Barely a resume at all. */
const WEAK_RESUME = `name: John Doe
i am a student. i know coding. i have done projects. i am hardworking.
i want job in IT company. my skills are many things.
hobbies: cricket, movies, music.`;

const ROLE = "Software Engineer";

// ═════════════════════════════════════════════════════════════════════════
// 1 — the rubric's own shape
// ═════════════════════════════════════════════════════════════════════════

test("the category budgets sum to exactly MAX_SCORE", () => {
  const total = Object.values(CATEGORY_POINTS).reduce((sum, n) => sum + n, 0);
  assert.equal(total, MAX_SCORE);
  assert.equal(MAX_SCORE, 100);
});

test("the section weights sum to the section budget", () => {
  const total = Object.values(SECTION_POINTS).reduce((sum, n) => sum + n, 0);
  assert.equal(total, CATEGORY_POINTS.sections);
});

test("impact bands are strictly descending so the first match is the best", () => {
  for (let i = 1; i < IMPACT_BANDS.length; i++) {
    assert.ok(
        IMPACT_BANDS[i].min < IMPACT_BANDS[i - 1].min,
        "impact bands must descend by threshold",
    );
    assert.ok(
        IMPACT_BANDS[i].points < IMPACT_BANDS[i - 1].points,
        "impact bands must descend by points",
    );
  }
});

test("bandPoints picks the first matching band and floors at 0", () => {
  const bands = [{min: 0.5, points: 18}, {min: 0.2, points: 7}];
  assert.equal(bandPoints(0.9, bands), 18);
  assert.equal(bandPoints(0.5, bands), 18, "inclusive threshold");
  assert.equal(bandPoints(0.3, bands), 7);
  assert.equal(bandPoints(0.19, bands), 0, "below every threshold");
});

// ═════════════════════════════════════════════════════════════════════════
// 2 — the reported bug: one number for every resume
// ═════════════════════════════════════════════════════════════════════════

test("deterministic: the same resume scores identically on every run", () => {
  const first = scoreResume(TYPICAL_RESUME, ROLE);
  for (let i = 0; i < 5; i++) {
    const again = scoreResume(TYPICAL_RESUME, ROLE);
    assert.equal(again.score, first.score, "the score must not drift");
    assert.deepEqual(
        again.categories.map((c) => [c.id, c.points]),
        first.categories.map((c) => [c.id, c.points]),
        "the breakdown must not drift either",
    );
  }
});

test("sensitive: a strong resume outscores a weak one by a wide margin", () => {
  const strong = scoreResume(STRONG_RESUME, ROLE).score;
  const typical = scoreResume(TYPICAL_RESUME, ROLE).score;
  const weak = scoreResume(WEAK_RESUME, ROLE).score;

  assert.ok(
      strong - weak >= 40,
      `strong (${strong}) must clearly beat weak (${weak}) — the reported bug ` +
      "was that both returned the same number",
  );
  assert.ok(strong > typical, `strong (${strong}) > typical (${typical})`);
  assert.ok(typical > weak, `typical (${typical}) > weak (${weak})`);
});

test("sensitive: adding a quantified achievement raises the score", () => {
  const before = scoreResume(TYPICAL_RESUME, ROLE).score;
  const after = scoreResume(
      TYPICAL_RESUME.replace(
          "- Worked on the company website and fixed bugs.",
          "- Reworked the company website, cutting its load time by 41%.",
      ),
      ROLE,
  ).score;

  assert.ok(after > before, `quantifying a bullet must help (${before} -> ${after})`);
});

test("sensitive: adding the target role's keywords raises the score", () => {
  const before = scoreResume(TYPICAL_RESUME, "Data Scientist").score;
  const after = scoreResume(
      `${TYPICAL_RESUME}\nPython, pandas, numpy, scikit-learn, TensorFlow, Jupyter, statistics`,
      "Data Scientist",
  ).score;

  assert.ok(after > before, `role keywords must help (${before} -> ${after})`);
});

test("sensitive: adding a missing section raises the score", () => {
  const withoutProjects = TYPICAL_RESUME.replace("PROJECTS\n", "");
  const withProjects = TYPICAL_RESUME;

  assert.ok(
      scoreResume(withProjects, ROLE).score >
      scoreResume(withoutProjects, ROLE).score,
      "a resume with a Projects section must score higher",
  );
});

// ═════════════════════════════════════════════════════════════════════════
// 3 — the score is always well-formed
// ═════════════════════════════════════════════════════════════════════════

test("total-preserving: the categories always sum to the score", () => {
  for (const resume of [TYPICAL_RESUME, STRONG_RESUME, WEAK_RESUME]) {
    const result = scoreResume(resume, ROLE);
    const sum = result.categories.reduce((total, c) => total + c.points, 0);
    assert.equal(result.score, sum, "score must equal the category total");
  }
});

test("every category stays inside its own budget", () => {
  for (const resume of [TYPICAL_RESUME, STRONG_RESUME, WEAK_RESUME]) {
    for (const category of scoreResume(resume, ROLE).categories) {
      assert.ok(category.points >= 0, `${category.id} must not go negative`);
      assert.ok(
          category.points <= category.max,
          `${category.id} scored ${category.points} over its ${category.max} budget`,
      );
    }
  }
});

test("the score is an integer in [0, 100] for every input", () => {
  const inputs = [
    TYPICAL_RESUME,
    STRONG_RESUME,
    WEAK_RESUME,
    "",
    "   ",
    "x".repeat(20000),
    "🎉".repeat(50),
  ];
  for (const input of inputs) {
    const {score} = scoreResume(input, ROLE);
    assert.ok(Number.isInteger(score), "score must be an integer");
    assert.ok(score >= 0 && score <= MAX_SCORE, `score ${score} out of range`);
  }
});

test("never throws on odd input, and a non-string scores 0", () => {
  for (const input of [null, undefined, 42, {}, [], NaN, true]) {
    const result = scoreResume(input, ROLE);
    assert.equal(result.score, 0, `${String(input)} should score 0, not throw`);
    assert.equal(result.categories.length, 7);
  }
});

test("a malformed or missing target role never throws", () => {
  for (const role of [undefined, null, "", "   ", "🧑‍💻", 123, "a".repeat(5000)]) {
    const result = scoreResume(TYPICAL_RESUME, role);
    assert.ok(Number.isInteger(result.score), "must produce a usable score");
  }
});

test("describeScore renders the number and every category", () => {
  const result = scoreResume(STRONG_RESUME, ROLE);
  const text = describeScore(result);

  assert.match(text, new RegExp(`DETERMINISTIC ATS SCORE: ${result.score}/100`));
  for (const category of result.categories) {
    assert.ok(text.includes(category.label), `missing ${category.label}`);
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 4 — section detection (the defect the smoke test caught)
// ═════════════════════════════════════════════════════════════════════════

test("isHeadingLine is case-insensitive — resumes shout their headings", () => {
  const aliases = SECTION_ALIASES.education;
  for (const line of ["EDUCATION", "Education", "education", "  EDUCATION  "]) {
    assert.ok(isHeadingLine(line, aliases), `${JSON.stringify(line)} is a heading`);
  }
});

test("isHeadingLine accepts decorated headings", () => {
  assert.ok(isHeadingLine("## Skills", SECTION_ALIASES.skills));
  assert.ok(isHeadingLine("- TECHNICAL SKILLS AND TOOLS", SECTION_ALIASES.skills));
  assert.ok(isHeadingLine("Experience:", SECTION_ALIASES.experience));
});

test("isHeadingLine rejects a passing mention inside a sentence", () => {
  const cases = [
    ["About the project we built last year", SECTION_ALIASES.summary],
    ["skills are many things", SECTION_ALIASES.skills],
    ["i have done projects in college", SECTION_ALIASES.projects],
    ["Rahul Verma", SECTION_ALIASES.summary],
    ["Library Management System", SECTION_ALIASES.projects],
  ];
  for (const [line, aliases] of cases) {
    assert.ok(
        !isHeadingLine(line, aliases),
        `${JSON.stringify(line)} must NOT be read as a heading`,
    );
  }
});

test("hasSection finds every core section in a normal resume", () => {
  const lines = TYPICAL_RESUME.split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
  for (const key of Object.keys(SECTION_POINTS)) {
    assert.ok(hasSection(lines, key), `the ${key} section must be detected`);
  }
});

test("hasSection finds nothing in a resume with no sections", () => {
  const lines = WEAK_RESUME.split("\n").map((line) => line.trim()).filter(Boolean);
  for (const key of Object.keys(SECTION_POINTS)) {
    assert.ok(!hasSection(lines, key), `${key} must not be detected`);
  }
});

// ═════════════════════════════════════════════════════════════════════════
// 5 — the individual signals
// ═════════════════════════════════════════════════════════════════════════

test("detectContact finds each element independently", () => {
  assert.deepEqual(
      detectContact("a@b.com"),
      {email: true, phone: false, link: false},
  );
  assert.deepEqual(
      detectContact("+91 98765 43210"),
      {email: false, phone: true, link: false},
  );
  assert.deepEqual(
      detectContact("github.com/someone"),
      {email: false, phone: false, link: true},
  );
  assert.deepEqual(
      detectContact("nothing here"),
      {email: false, phone: false, link: false},
  );
});

test("extractBullets recognises the usual list markers", () => {
  const lines = [
    "- dashed bullet",
    "* starred bullet",
    "• unicode bullet",
    "1. numbered bullet",
    "2) paren numbered bullet",
    "not a bullet",
    "HISTORY",
  ];
  const bullets = extractBullets(lines);
  assert.equal(bullets.length, 5);
  assert.deepEqual(
      bullets.map((b) => b.text),
      [
        "dashed bullet",
        "starred bullet",
        "unicode bullet",
        "numbered bullet",
        "paren numbered bullet",
      ],
  );
});

test("a heading is not mistaken for a bullet, and vice versa", () => {
  const bullets = extractBullets(["- Java Programming (NPTEL)", "PROJECTS"]);
  assert.equal(bullets.length, 1);
  assert.equal(bullets[0].text, "Java Programming (NPTEL)");
});

test("roleKeywords prefers the most specific role match", () => {
  const dataScientist = roleKeywords("Data Scientist");
  assert.ok(dataScientist.includes("scikit"), "should be the data-scientist list");

  const fullStack = roleKeywords("Full Stack Developer");
  assert.ok(fullStack.includes("react"), "should be the full-stack list");

  assert.deepEqual(roleKeywords("Senior   "), [], "a stopword-only role has no set");
  assert.deepEqual(roleKeywords(""), []);
  assert.deepEqual(roleKeywords(undefined), []);
});

test("matchedKeywords matches substrings, so mysql satisfies sql", () => {
  const matched = matchedKeywords("java mysql git", ["java", "sql", "rust"]);
  assert.deepEqual(matched, ["java", "sql"]);
});
