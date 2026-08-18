/**
 * CampusConnect v8.9 — Career Role Taxonomy
 *
 * Deterministic role definitions consumed by the recommendation engine.
 * Every role carries:
 *   - id: stable slug (used as `targetRole` in recommendation documents)
 *   - title: human-readable name
 *   - requiredSkills: skills expected for the role (match weight 3)
 *   - niceToHaveSkills: complementary skills (match weight 1.5)
 *   - keywords: alias signals (career signals / project titles) that map a
 *     student's stated intent to this role (match weight 2)
 *
 * Roles are intentionally broad (the same layer the app surfaces elsewhere)
 * and are not hardcoded to a tiny list — extend this file to grow the
 * taxonomy without touching the engine.
 *
 * REQUIRED-skills are a scoring input, NOT a hard gate: no student is ever
 * excluded from a role recommendation for missing a skill — that is what the
 * Skill-Gap match type reports instead. Hard gates live exclusively in the
 * placement eligibility rules (`engine.js` → `checkMandatoryEligibility`).
 */

/**
 * Tokenize + normalize a skill list the same way the legacy engine did
 * (`normalizeTokens` in index.js): split on commas/spaces/slashes, lowercase,
 * trim, drop single-character tokens. Exported for reuse by the engine.
 *
 * @param {Array<string|number>} values
 * @returns {Set<string>} Normalized tokens
 */
function normalizeTokens(values) {
  return new Set(
    (values || [])
      .flatMap((value) => String(value || '').split(/[,\s/]+/g))
      .map((token) => token.trim().toLowerCase())
      .filter((token) => token.length > 1)
  );
}

/**
 * Intersection size of two sets.
 * @param {Set<string>} setA
 * @param {Set<string>} setB
 * @returns {number}
 */
function intersectionCount(setA, setB) {
  let count = 0;
  for (const value of setA) {
    if (setB.has(value)) count++;
  }
  return count;
}

/**
 * Normalize a single skill string into matchable tokens ("REST API" →
 * {"rest","api"}, "UI/UX" → {"ui","ux"}). The engine's student signal sets
 * are built with the same splitter, so comparisons are consistent.
 *
 * @param {string} skill
 * @returns {Set<string>}
 */
function skillTokens(skill) {
  return new Set(
    String(skill || '')
      .toLowerCase()
      .split(/[,\s/]+/g)
      .filter((token) => token.length > 1)
  );
}

/**
 * Match a single role against the student's normalized signals.
 *
 * Score = weighted-coverage fit percentage:
 *   required skills weight 3 each, nice-to-have 1.5 each — the matched
 *   weight over the role's total weight ⇒ an explainable "48% role fit".
 *   Up to +12 bonus for career-interest keyword alignment.
 *
 * @param {object} role - A role from [CAREER_ROLES]
 * @param {Set<string>} skills - Normalized student skill tokens
 * @param {Set<string>} projectTokens - Normalized project technology/title tokens
 * @param {Set<string>} careerSignals - Normalized career interest/role tokens (split)
 * @param {Set<string>} [careerPhrases] - Raw career interest/role phrases
 *   (e.g. "Mobile Developer") used to match multi-word role keywords
 * @param {Set<string>} certTokens - Normalized certification title tokens
 * @param {Set<string>} [evidenceTokens] - v8.9.3 (R1c): normalized tokens from
 *   demonstrated work experience (role/company/description/technologies),
 *   project titles/tech and certification titles. Consulted (a) to satisfy a
 *   role skill when ALL its tokens appear in the evidence — free text like an
 *   internship description naming "Dart", "Firebase", "REST", "Git" counts as
 *   demonstrated proof of those skills — and (b) as career-intent keywords.
 *   Structured skill/project/cert sets keep their ANY-token semantics; the
 *   free-text evidence pool requires ALL tokens so a description casually
 *   containing "data" cannot satisfy "Data Visualization".
 * @returns {{roleId: string, title: string, score: number, matchedSkills: string[], missingSkills: string[]}}
 */
function matchRole(role, {skills, projectTokens, careerSignals, careerPhrases, certTokens, evidenceTokens}) {
  const matchedSkills = [];
  let matchedWeight = 0;
  let totalWeight = 0;
  const phraseSet = careerPhrases || new Set();

  /**
   * A role skill is "present" when ANY of its normalized tokens appears in
   * the student's skill/project/cert sets — consistent with how student
   * skills are tokenized ("UI/UX" ⇒ {ui, ux}).
   *
   * v8.9.3 (R1c): the free-text evidence pool is consulted with a stricter
   * ALL-tokens rule (see the jsdoc above) so descriptive text proves a skill
   * only when the whole skill phrase is present.
   */
  const skillHas = (skill) => {
    const tokens = [...skillTokens(skill)];
    if (tokens.length === 0) return false;
    const structuredHit = tokens.some((token) =>
      skills.has(token) || projectTokens.has(token) || certTokens.has(token)
    );
    if (structuredHit) return true;
    if (evidenceTokens && tokens.every((token) => evidenceTokens.has(token))) {
      return true;
    }
    return false;
  };

  for (const skill of role.requiredSkills) {
    totalWeight += 3;
    if (skillHas(skill)) {
      matchedWeight += 3;
      matchedSkills.push(skill);
    }
  }

  for (const skill of role.niceToHaveSkills) {
    totalWeight += 1.5;
    if (skillHas(skill)) {
      matchedWeight += 1.5;
      if (!matchedSkills.includes(skill)) matchedSkills.push(skill);
    }
  }

  let keywordBonus = 0;
  for (const keyword of role.keywords) {
    const key = keyword.toLowerCase();
    // Fast path: the exact phrase is present verbatim in the career phrases
    // ("app development" matches a keyword alias "App Development").
    if (careerSignals.has(key) || phraseSet.has(key)) {
      keywordBonus += 2;
      continue;
    }
    // v8.9.3 (R1b): token-overlap fallback. `careerSignals` is a TOKENIZED
    // set (`careerInterest: "App Development"` ⇒ {app, development}) while
    // role keywords are multi-word phrases ("App Developer"). Exact lookups
    // could therefore NEVER fire for this student. Instead, require a
    // MAJORITY of the keyword's tokens to appear in the student's tokenized
    // career signals or demonstrated-evidence pool — "App Developer" ⇔
    // {app, development} shares 2/2 tokens ⇒ bonus fires; a stray one-token
    // overlap ("Developer" ⇔ "Data Analyst") never does.
    const kwTokens = [...skillTokens(key)];
    if (kwTokens.length <= 1) continue;
    let overlap = 0;
    for (const token of kwTokens) {
      if (careerSignals.has(token) || (evidenceTokens && evidenceTokens.has(token))) {
        overlap++;
      }
    }
    if (overlap >= Math.ceil(kwTokens.length / 2)) {
      keywordBonus += 2;
    }
  }

  const basePercent = totalWeight > 0 ? (matchedWeight / totalWeight) * 100 : 0;
  const score = Math.min(100, Math.round(basePercent + Math.min(12, keywordBonus)));

  const allRoleSkills = [...role.requiredSkills, ...role.niceToHaveSkills];
  const missingSkills = allRoleSkills.filter((skill) => !skillHas(skill));

  return {
    roleId: role.id,
    title: role.title,
    score,
    matchedSkills,
    missingSkills,
  };
}

/**
 * The career-role taxonomy. Extend here to grow the set.
 */
const CAREER_ROLES = [
  {
    id: 'software_developer',
    title: 'Software Developer',
    requiredSkills: [
      'Java', 'Python', 'C++', 'JavaScript', 'Data Structures', 'Algorithms',
      'Git', 'SQL',
    ],
    niceToHaveSkills: [
      'Spring', 'React', 'Node.js', 'Docker', 'REST', 'Microservices',
      'System Design', 'AWS',
    ],
    keywords: [
      'Software Developer', 'Software Engineer', 'SDE', 'Developer',
      'Full Stack', 'Backend Developer', 'Programming',
    ],
  },
  {
    id: 'web_developer',
    title: 'Web Developer',
    requiredSkills: [
      'HTML', 'CSS', 'JavaScript', 'React', 'Node.js',
    ],
    niceToHaveSkills: [
      'TypeScript', 'Next.js', 'Tailwind', 'MongoDB', 'Firebase', 'REST',
      'Git',
    ],
    keywords: [
      'Web Developer', 'Frontend Developer', 'Front End', 'UI Developer',
      'Web Development',
    ],
  },
  {
    id: 'mobile_developer',
    title: 'Mobile Developer',
    requiredSkills: [
      'Flutter', 'Dart', 'Android', 'Kotlin', 'Swift', 'iOS',
    ],
    niceToHaveSkills: [
      'Firebase', 'React Native', 'REST', 'SQLite', 'Git', 'UI/UX',
    ],
    keywords: [
      'Mobile Developer', 'Android Developer', 'iOS Developer',
      'Flutter Developer', 'App Developer',
      // v8.9.3 (R1b): the user's stored careerInterest is "App Development"
      // — these verbatim phrases land in careerPhrases so the exact-match
      // fast path fires without any token overlap.
      'App Development', 'Mobile App Development', 'App Dev',
    ],
  },
  {
    id: 'data_analyst',
    title: 'Data Analyst',
    requiredSkills: [
      'SQL', 'Python', 'Excel', 'Statistics', 'Data Visualization',
    ],
    niceToHaveSkills: [
      'Pandas', 'Power BI', 'Tableau', 'R', 'NumPy', 'ETL', 'Machine Learning',
    ],
    keywords: [
      'Data Analyst', 'Data Analysis', 'Business Analyst', 'Analytics',
    ],
  },
  {
    id: 'ai_ml_engineer',
    title: 'AI/ML Engineer',
    requiredSkills: [
      'Python', 'Machine Learning', 'Deep Learning', 'TensorFlow',
      'PyTorch', 'NumPy',
    ],
    niceToHaveSkills: [
      'NLP', 'Computer Vision', 'Scikit-learn', 'Pandas', 'MLOps', 'Docker',
      'Statistics',
    ],
    keywords: [
      'AI', 'ML Engineer', 'Machine Learning', 'Artificial Intelligence',
      'Data Scientist', 'Deep Learning',
    ],
  },
  {
    id: 'cloud_engineer',
    title: 'Cloud Engineer',
    requiredSkills: [
      'AWS', 'Azure', 'GCP', 'Docker', 'Kubernetes', 'Linux',
    ],
    niceToHaveSkills: [
      'Terraform', 'CI/CD', 'Jenkins', 'Networking', 'Python', 'Git',
    ],
    keywords: [
      'Cloud Engineer', 'Cloud Architect', 'AWS Engineer', 'DevOps',
    ],
  },
  {
    id: 'devops_engineer',
    title: 'DevOps Engineer',
    requiredSkills: [
      'Docker', 'Kubernetes', 'CI/CD', 'Linux', 'Jenkins', 'Git',
    ],
    niceToHaveSkills: [
      'Terraform', 'AWS', 'Ansible', 'Prometheus', 'Python', 'Bash',
    ],
    keywords: [
      'DevOps', 'DevOps Engineer', 'Site Reliability', 'SRE',
    ],
  },
  {
    id: 'cybersecurity_analyst',
    title: 'Cybersecurity Analyst',
    requiredSkills: [
      'Network Security', 'Linux', 'SIEM', 'Penetration Testing', 'Firewall',
    ],
    niceToHaveSkills: [
      'Cryptography', 'Ethical Hacking', 'Python', 'Risk Management', 'IDS/IPS',
    ],
    keywords: [
      'Cybersecurity', 'Security Analyst', 'Cyber Security', 'InfoSec',
      'Security Engineer',
    ],
  },
  {
    id: 'database_administrator',
    title: 'Database Administrator',
    requiredSkills: [
      'SQL', 'MySQL', 'PostgreSQL', 'MongoDB', 'Database Design',
    ],
    niceToHaveSkills: [
      'Redis', 'Oracle', 'Backup', 'Performance Tuning', 'Python', 'Linux',
    ],
    keywords: ['Database', 'DBA', 'Data Engineer'],
  },
];

module.exports = {
  CAREER_ROLES,
  normalizeTokens,
  intersectionCount,
  matchRole,
};
