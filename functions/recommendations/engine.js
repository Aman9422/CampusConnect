/**
 * CampusConnect v8.9 — Deterministic Recommendation Engine
 *
 * The single scoring brain behind `refreshRecommendationsForStudent`.
 *
 * Produces the complete recommendation list for a student:
 *   - `mentor`  (legacy v7.4 scoring — preserved)
 *   - `job`     (legacy v7.4 opportunity scoring — preserved)
 *   - `role`    (NEW v8.9 career-role match — Phase 4)
 *   - `placement` (NEW v8.9 placement match with hard eligibility — Phase 5)
 *   - `skill`   (NEW v8.9 skill-gap — Phase 6)
 *   - `portfolio` (v8.9.1 portfolio-first gate)
 *   - `chat`    (legacy nudge)
 *
 * v8.9.1 PORTFOLIO-FIRST CONTRACT:
 *   Every personalized recommendation type (role / placement / skill /
 *   mentor / job) is gated behind `hasMeaningfulPortfolioContent` — real,
 *   demonstrable evidence (skills, project technologies, or an ATS-scored
 *   resume). Stated intent alone (the REQUIRED career-interest field at
 *   profile setup) is NOT evidence and does NOT unlock recommendations.
 *   A student with no portfolio evidence receives exactly ONE card: the
 *   `portfolio` gate ("Complete your portfolio first"), which routes to the
 *   portfolio builder. When the portfolio gains evidence, the gate card
 *   disappears and the engine emits real, personalized matches.
 *
 * HARD-CONSTRAINT CONTRACT (Phase 7):
 *   - Mandatory eligibility (deadline, applied, CGPA, year, program/branch)
 *     is deterministic here and ALWAYS wins. AI can never override it.
 *   - AI is only consulted AFTER this module returns, to enrich the top-N
 *     explanations. If AI fails, the deterministic reasons are stored as-is.
 */

const {
  CAREER_ROLES,
  normalizeTokens,
  intersectionCount,
  matchRole,
} = require('./career_roles');

// v8.9.3 (R2): minimum role-fit score for a career-role recommendation to be
// emitted. Lowered from 30 → 20 so a thin-but-real portfolio (one core skill
// + one project + stated intent) still surfaces its best role match instead
// of returning zero role cards. Intent-only students remain gated by
// `hasMeaningfulPortfolioContent`, so this never revives the "Software
// Engineer for everyone" noise.
const ROLE_MATCH_THRESHOLD = 20;

// ============================================================
// PORTFOLIO EXTRACTION (mirror of the client's MB17 tolerant read)
// ============================================================

/**
 * Extract the portfolio map from a user document, accepting BOTH the
 * canonical nested shape (`userData.portfolio.{...}`) and the flattened
 * root-level `portfolio.*` dotted keys written by console/legacy editors.
 *
 * @param {object|null} userData
 * @returns {object} Portfolio map (empty object when missing)
 */
function extractPortfolio(userData) {
  if (!userData || typeof userData !== 'object') return {};

  const nested = userData.portfolio;
  if (nested && typeof nested === 'object' && !Array.isArray(nested)) {
    return nested;
  }

  const unflattened = {};
  for (const key of Object.keys(userData)) {
    if (key.startsWith('portfolio.') && key.length > 'portfolio.'.length) {
      const path = key.substring('portfolio.'.length).split('.');
      let cursor = unflattened;
      for (let i = 0; i < path.length - 1; i++) {
        cursor[path[i]] = cursor[path[i]] || {};
        cursor = cursor[path[i]];
      }
      cursor[path[path.length - 1]] = userData[key];
    }
  }
  return unflattened;
}

// ============================================================
// STUDENT SIGNAL EXTRACTION
// ============================================================

/**
 * Normalize the student's profile + portfolio into matchable signal sets.
 *
 * @param {object} userData - Raw `users/{uid}` document
 * @param {object} portfolio - Extracted portfolio map
 * @param {object} [options] - {resumeData} from the resume-review trigger
 * @returns {object}
 */
function extractUserSignals(userData, portfolio, options = {}) {
  const portfolioSkills = Array.isArray(portfolio.skills)
    ? portfolio.skills.map(
        (skill) => (typeof skill === 'string' ? skill : (skill && skill.name) || ''),
      )
    : [];

  const projects = Array.isArray(portfolio.projects) ? portfolio.projects : [];
  const projectTokens = normalizeTokens(
    projects.flatMap((p) => {
      const tech = Array.isArray(p && p.technologies) ? p.technologies : [];
      return [p && p.title, ...tech];
    }),
  );

  const certs = Array.isArray(portfolio.certifications) ? portfolio.certifications : [];
  const certTokens = normalizeTokens(
    certs.flatMap((cert) => {
      const parts = [];
      if (cert && cert.title) parts.push(cert.title);
      if (cert && cert.issuer) parts.push(cert.issuer);
      return parts;
    }),
  );

  // v8.9.3 (R1c): experience descriptions/roles/companies/technologies are
  // demonstrated evidence — a Flutter internship description mentions Dart,
  // Firebase, REST and Git. Previously ignored entirely; now tokenized into
  // the role-match evidence pool (see evidenceTokens below). `skills` stays
  // the clean skill-overlap set used by placement matching, so this pool
  // never inflates placement overlap.
  const experience = Array.isArray(portfolio.experience) ? portfolio.experience : [];
  const experienceTokens = normalizeTokens(
    experience.flatMap((exp) => {
      if (!exp || typeof exp !== 'object') return [];
      const tech = Array.isArray(exp.technologies) ? exp.technologies : [];
      return [exp.role, exp.company, exp.description, ...tech];
    }),
  );

  const portfolioPrefs =
    portfolio.preferences && typeof portfolio.preferences === 'object'
      ? portfolio.preferences
      : {};
  const preferredRoles = Array.isArray(portfolioPrefs.preferredRoles)
    ? portfolioPrefs.preferredRoles
    : [];
  const careerObjective = String(
    portfolioPrefs.careerObjective || userData.careerInterest || '',
  ).trim();

  const careerData = userData.career && typeof userData.career === 'object' ? userData.career : {};
  // v8.9.3 (R1a): the nested `career.careerInterest` is where the REQUIRED
  // profile-setup field ("Career Interest") is actually persisted (the Flutter
  // profile model writes it into the `career` map as `career.careerInterest`;
  // root `userData.careerInterest` is a legacy/flat fallback that is NOT
  // present on most student docs). Previously only root careerInterest was
  // read, so a student like Ajayak with `career.careerInterest = "App
  // Development"` produced EMPTY careerSignals — the keyword bonus never
  // fired and role matching starved. This line closes that gap.
  const nestedCareerInterest = String(careerData.careerInterest || '').trim();
  // Raw phrase signals keep multi-word role keywords matchable ("Mobile
  // Developer" is a single preferred-role entry; tokenization splits it).
  const careerPhrases = new Set(
    [
      ...(Array.isArray(careerData.interests) ? careerData.interests : []),
      ...(Array.isArray(careerData.preferredRoles) ? careerData.preferredRoles : []),
      ...preferredRoles,
      careerObjective,
      nestedCareerInterest,
    ]
      .map((entry) => String(entry || '').trim().toLowerCase())
      .filter((entry) => entry.length > 0),
  );
  const careerSignals = normalizeTokens([...careerPhrases]);

  const academic = userData.academic && typeof userData.academic === 'object'
    ? userData.academic
    : {};
  const resume = portfolio.resume && typeof portfolio.resume === 'object'
    ? portfolio.resume
    : {};

  const resumeMissing =
    options.resumeData && Array.isArray(options.resumeData.missingKeywords)
      ? options.resumeData.missingKeywords
      : [];

  const skills = new Set([
    ...normalizeTokens(userData.skills || []),
    ...normalizeTokens(portfolioSkills),
    ...projectTokens,
  ]);

  const atsScore = typeof resume.latestATSScore === 'number'
    ? Math.max(0, Math.min(100, resume.latestATSScore))
    : null;

  // v8.9.1 (portfolio-first): does the student have REAL portfolio content?
  // Profile-level career interest is NOT portfolio content — the portfolio
  // gate intentionally requires portfolio data before role/placement/skill
  // recommendations are emitted.
  const hasExperience = Array.isArray(portfolio.experience) && portfolio.experience.length > 0;
  const hasLanguages = Array.isArray(portfolio.languages) && portfolio.languages.length > 0;
  const portfolioObjective = String(portfolioPrefs.careerObjective || '').trim();
  const hasPortfolioPrefs = preferredRoles.length > 0 || portfolioObjective.length > 0;
  const hasResume =
    !!(resume && (resume.hasResume === true || resume.fileName || resume.storagePath || resume.url));
  const hasPortfolioContent =
    portfolioSkills.length > 0 ||
    projects.length > 0 ||
    certs.length > 0 ||
    hasExperience ||
    hasLanguages ||
    hasPortfolioPrefs ||
    hasResume;

  // v8.9.1 (portfolio-first): the single gate used to decide whether the
  // student has ENOUGH demonstrable evidence to unlock career matching.
  // Stated intent (career interest / preferred roles) is NOT evidence —
  // real skills, project technologies or an ATS-scored resume are. Every
  // personalized recommendation emitter (role/placement/skill/mentor/job)
  // checks this flag; when it is false, ONLY the portfolio gate card is
  // emitted (see buildPortfolioGateRecommendations).
  const hasMeaningfulPortfolioContent =
    skills.size > 0 || projectTokens.size > 0 || atsScore !== null;

  return {
    skills,
    projectTokens,
    careerSignals,
    careerPhrases,
    certTokens,
    experienceTokens,
    // v8.9.3 (R1c): combined demonstrated-evidence pool for role matching —
    // free-text experience, project titles/tech and certification titles.
    // Kept separate from `skills` so placement overlap (u.skills) stays
    // strictly skill-based.
    evidenceTokens: new Set([...experienceTokens, ...certTokens, ...projectTokens]),
    program: String(academic.program || '').toUpperCase(),
    year: Number(academic.year) || 0,
    cgpa: Number(academic.cgpa) || 0,
    department: userData.department || null,
    atsScore,
    resumeMissing: normalizeTokens(resumeMissing),
    langTokens: normalizeTokens(portfolio.languages || []),
    hasPortfolioContent,
    hasMeaningfulPortfolioContent,
  };
}

// ============================================================
// MANDATORY ELIGIBILITY (deterministic — never AI-decided)
// ============================================================

/**
 * Check mandatory placement eligibility (mirror of the client
 * `EligibilityEngine` in `lib/services/eligibility_engine.dart`).
 * Skills/preferences are NOT hard gates.
 *
 * ARCH-3: These rules are mirrored client-side. Both implementations
 * MUST stay in sync. See `docs/eligibility_rules.md` for the canonical
 * rule set and sync policy.
 *
 * @param {object} placement - Raw placement document
 * @param {object} u - Output of extractUserSignals
 * @param {Set<string>} appliedIds - Placement ids this student already applied to
 * @returns {{eligible: boolean, reason: string|null}}
 */
function checkMandatoryEligibility(placement, u, appliedIds) {
  const now = Date.now();
  const deadline = placement.deadline && placement.deadline.toDate
    ? placement.deadline.toDate().getTime()
    : typeof placement.deadline === 'number'
      ? placement.deadline
      : null;

  if (deadline !== null && deadline < now) {
    return {eligible: false, reason: 'Application deadline has passed'};
  }

  if (appliedIds.has(placement.id)) {
    return {eligible: false, reason: 'You have already applied'};
  }

  const req = placement.requirements && typeof placement.requirements === 'object'
    ? placement.requirements
    : {};
  const minCgpa = typeof req.minCgpa === 'number' ? req.minCgpa : null;
  const allowedYears = Array.isArray(req.allowedYears) ? req.allowedYears : [];
  const programs = Array.isArray(req.programs)
    ? req.programs.map((p) => String(p).toUpperCase())
    : [];
  const branches = Array.isArray(req.branches)
    ? req.branches.map((b) => String(b).toUpperCase())
    : [];

  const failures = [];
  if (minCgpa !== null && u.cgpa < minCgpa) {
    failures.push(`CGPA ${u.cgpa} below required ${minCgpa}`);
  }
  if (allowedYears.length > 0 && !allowedYears.includes(u.year)) {
    failures.push(`Year ${u.year} not eligible`);
  }
  if (programs.length > 0 && !programs.includes(u.program)) {
    failures.push(`Program ${u.program || '—'} not eligible`);
  } else if (branches.length > 0 && !branches.includes(u.program)) {
    failures.push('Branch not eligible');
  }

  if (failures.length > 0) {
    return {eligible: false, reason: failures[0]};
  }
  return {eligible: true, reason: null};
}

// ============================================================
// PLACEMENT MATCHING (Phase 5)
// ============================================================

/**
 * Classify an eligible placement into a match tier.
 *
 * @returns {{tier: 'strong'|'potential'|'skill_gap', overlap: number,
 *   preferenceBonus: number, matchedSkills: string[], missingSkills: string[]}}
 */
function classifyPlacementMatch(placement, u) {
  const reqSkills = Array.isArray(placement.requirements && placement.requirements.skills)
    ? placement.requirements.skills
    : [];
  const freeTextSkills = Array.isArray(placement.skills) ? placement.skills : [];
  const allReqSkills = [...new Set([...reqSkills, ...freeTextSkills])];

  let overlap = 0;
  if (allReqSkills.length > 0) {
    overlap = intersectionCount(u.skills, normalizeTokens(allReqSkills)) / allReqSkills.length;
  }

  const roleSignals = normalizeTokens([placement.role || '', placement.company || '']);
  const preferenceBonus = intersectionCount(u.careerSignals, roleSignals);

  let tier = 'skill_gap';
  if (overlap >= 0.6 || (overlap >= 0.4 && preferenceBonus > 0)) {
    tier = 'strong';
  } else if (overlap >= 0.3 || preferenceBonus > 0) {
    tier = 'potential';
  }

  const matchedSkills = allReqSkills.filter((skill) => u.skills.has(skill.toLowerCase()));
  const missingSkills = allReqSkills.filter((skill) => !u.skills.has(skill.toLowerCase()));

  return {tier, overlap, preferenceBonus, matchedSkills, missingSkills};
}

/**
 * Score an eligible placement into a 0–100 recommendation score.
 * Blend: foundation 35 + skill overlap (≤40) + preference (≤15) + ATS (≤10).
 */
function scorePlacement({tier, overlap}, u) {
  let score = 35;
  score += Math.min(40, Math.round(overlap * 40));
  if (tier === 'strong') score += 8;
  if (tier === 'potential') score += 4;
  if (u.atsScore !== null) score += Math.min(10, Math.round(u.atsScore / 10));
  return Math.min(100, score);
}

function buildPlacementReason(placement, match) {
  if (match.tier === 'strong') {
    return `Strong match — you meet the eligibility criteria and your skills align with the ${placement.role || 'role'} at ${placement.company || 'this company'}.`;
  }
  if (match.tier === 'potential') {
    return `Potential match — you are eligible, and some of your skills or career interests align with this ${placement.role || 'role'}.`;
  }
  return 'Eligible, but this role highlights skills you have not demonstrated yet — see the suggested improvements.';
}

/**
 * Build the placement recommendation documents for eligible placements.
 *
 * @returns {Array<object>} Placement recommendation payloads (max 4)
 */
function buildPlacementRecommendations(placements, u, appliedIds, userId) {
  // v8.9.1 portfolio-first gate: placement matching requires demonstrable
  // evidence (skills / project technologies / ATS-scored resume). Stated
  // intent alone (career interest) is not enough — the portfolio gate card
  // is emitted instead (see buildPortfolioGateRecommendations).
  if (!u.hasMeaningfulPortfolioContent) {
    return [];
  }

  const results = [];
  for (const placement of placements) {
    if (!placement || placement.isActive === false) continue;

    const eligibility = checkMandatoryEligibility(placement, u, appliedIds);
    // Do NOT recommend opportunities for which the student clearly fails
    // mandatory eligibility requirements (Phase 5).
    if (!eligibility.eligible) continue;

    const match = classifyPlacementMatch(placement, u);

    // v8.9.1 relevance gate: a placement with ZERO skill overlap AND ZERO
    // career-interest alignment is irrelevant — it would land in the
    // 'skill_gap' tier at the 35 baseline purely because the student is
    // eligible. That is exactly the reported noise ("Security Operations at
    // TCS" for an app-development-focused student). Never recommend it.
    if (match.overlap === 0 && match.preferenceBonus === 0) {
      continue;
    }

    const score = scorePlacement(match, u);

    const tierLabel = match.tier === 'strong'
      ? 'Strong Match'
      : match.tier === 'potential'
        ? 'Potential Match'
        : 'Skill Gap';

    results.push({
      id: `placement_${placement.id}`,
      userId,
      type: 'placement',
      priority: score >= 70 ? 'high' : score >= 50 ? 'medium' : 'low',
      title: `${placement.role || 'Role'} at ${placement.company || 'Company'}`,
      description: `${tierLabel} · ${score}% match`,
      score,
      isActive: true,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      source: 'placement',
      opportunityId: placement.id,
      skillsMatched: match.matchedSkills.slice(0, 8),
      skillsMissing: match.missingSkills.slice(0, 8),
      reason: buildPlacementReason(placement, match),
      metadata: {
        placementId: placement.id,
        matchTier: match.tier,
        skillOverlap: Math.round(match.overlap * 100),
      },
    });
  }

  results.sort((a, b) => b.score - a.score);
  return results.slice(0, 4);
}

// ============================================================
// PORTFOLIO-FIRST GATE (v8.9.1)
// ============================================================

/**
 * Build a "complete your portfolio first" recommendation for students who
 * have no demonstrable portfolio content yet.
 *
 * The student may have a REQUIRED career interest, but without skills,
 * projects or a resume the engine cannot produce meaningful placement,
 * role, skill-gap, mentor or job rows. Instead of emission noise, surface
 * ONE actionable card that gates ALL personalized recommendations behind
 * portfolio completion.
 *
 * @param {object} u - Output of extractUserSignals
 * @param {string} userId
 * @returns {Array<object>} Empty when portfolio evidence exists, else one card
 */
function buildPortfolioGateRecommendations(u, userId) {
  if (u.hasMeaningfulPortfolioContent) {
    return [];
  }

  return [{
    id: 'portfolio_ready',
    userId,
    type: 'portfolio',
    priority: 'high',
    title: 'Complete your portfolio first',
    description: 'Unlock personalized placements, roles & skill-gap recommendations',
    score: 70,
    isActive: true,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    source: 'portfolio_gate',
    reason: 'Your recommendations are built from your demonstrated skills, projects and resume. Add them to your portfolio so the AI can match you to the right placements, roles and skill gaps.',
    suggestedAction: 'Add your skills, projects and resume to your portfolio to unlock personalized recommendations.',
    metadata: {action: 'open_portfolio'},
  }];
}

// ============================================================
// CAREER-ROLE MATCHING (Phase 4)
// ============================================================

function buildRoleReason(match) {
  if (match.matchedSkills.length > 0) {
    return (
      `Your profile shows ${match.matchedSkills.slice(0, 3).join(', ')}${match.matchedSkills.length > 3 ? ' and more' : ''}, which aligns with the ${match.title} role.`
    );
  }
  return `Your stated career interests align with the ${match.title} role.`;
}

/**
 * Build the top career-role recommendation documents.
 *
 * @returns {Array<object>} Role recommendation payloads (max 2)
 */
function buildRoleRecommendations(u, userId) {
  // v8.9.1 portfolio-first gate: career-role matching requires demonstrable
  // evidence too. A student who only stated a career interest (no skills /
  // projects / resume-ATS) must not receive "Career match: Software
  // Engineer" cards — the portfolio gate card is emitted instead. Without
  // evidence, matchRole's keyword bonus alone would surface a role card
  // that is exactly the "Software Engineer still coming" report.
  if (!u.hasMeaningfulPortfolioContent) {
    return [];
  }

  const matches = CAREER_ROLES
    .map((role) => matchRole(role, {
      skills: u.skills,
      projectTokens: u.projectTokens,
      careerSignals: u.careerSignals,
      careerPhrases: u.careerPhrases,
      certTokens: u.certTokens,
      // v8.9.3 (R1c): demonstrated evidence pool (experience descriptions,
      // certifications, project titles/tech) lets free-text internship
      // descriptions prove role skills ("Worked on Flutter apps… integrated
      // REST APIs… Firebase services" ⇒ Dart/Firebase/REST/Git matched).
      evidenceTokens: u.evidenceTokens,
    }))
    // v8.9.3 (R2): threshold lowered 30 → 20 so a thin-but-real portfolio
    // (one core skill + one project + stated intent) still surfaces its best
    // role match; named constant keeps the engine tunable.
    .filter((match) => match.score >= ROLE_MATCH_THRESHOLD)
    .sort((a, b) => b.score - a.score)
    .slice(0, 2);

  return matches.map((match) => ({
    id: `role_${match.roleId}`,
    userId,
    type: 'role',
    priority: match.score >= 60 ? 'high' : 'medium',
    title: `Career match: ${match.title}`,
    description: `${match.score}% role fit`,
    score: match.score,
    isActive: true,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
    source: 'career_role',
    targetRole: match.roleId,
    skillsMatched: match.matchedSkills.slice(0, 8),
    skillsMissing: match.missingSkills.slice(0, 8),
    reason: buildRoleReason(match),
    metadata: {roleId: match.roleId},
  }));
}

// ============================================================
// v9.0 (Phase 2): SKILL-GAP INTELLIGENCE REMOVED
// ============================================================
// The deterministic engine no longer emits `skill_*` rows. The fabricated
// "score: Math.min(100, 50 + count * 8)" percentage (Swift/Android/Kotlin/iOS
// all "66%") and the "Learn: X" cards are gone. Career reasoning is owned by
// the AI Career Coach (functions/recommendations/career_coach.js), which
// returns structured, validated recommendations — never tech-tag lists.

// ============================================================
// LEGACY MATCHERS (mentor + job + nudge — preserved from v7.4)
// ============================================================

/**
 * Build the generic "Use AI Career Assistant" nudge. Exposed as a helper so
 * the portfolio-gated legacy branch can return the nudge without scoring
 * jobs or mentors for intent-only students.
 *
 * @param {object} u - Output of extractUserSignals
 * @param {string} userId
 * @returns {object} Nudge recommendation payload
 */
function _buildNudgeRecommendation(u, userId) {
  return {
    id: 'nudge_ai_chat',
    userId,
    type: 'chat',
    priority: 'medium',
    title: 'Use AI Career Assistant',
    description: 'Get interview Q&A simulation, skill-gap analysis, and resume guidance.',
    score: 65,
    isActive: true,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
    source: 'nudge',
    metadata: {action: 'open_ai_chat'},
  };
}

/**
 * Build the legacy mentor + job + nudge recommendations. Scoring matches the
 * original `refreshRecommendationsForStudent` logic.
 *
 * @returns {{mentor: Array, job: Array, nudge: object}}
 */
function buildLegacyRecommendations(userData, u, alumniDocs, opportunityDocs, userId) {
  // v8.9.1 portfolio-first gate: mentor/job matching also requires
  // demonstrable evidence. A student with only a career interest must not
  // receive legacy "job" cards for random opportunities or "mentor" cards
  // scored purely on the stated intent — the portfolio gate card is emitted
  // instead. The nudge stays (it is a generic action, not a personal match).
  if (!u.hasMeaningfulPortfolioContent) {
    return {mentor: [], job: [], nudge: _buildNudgeRecommendation(u, userId)};
  }

  const legacyCareerSignals = u.careerSignals;
  const studentSkills = u.skills;
  const resumeMissing = u.resumeMissing;

  const mentorRecommendations = [];
  for (const alumni of alumniDocs) {
    if (alumni.id && alumni.id === userId) continue;
    const alumniSkills = normalizeTokens(alumni.skills || []);
    const overlapSkills = intersectionCount(studentSkills, alumniSkills);

    let score = overlapSkills * 18;
    if (legacyCareerSignals.has((alumni.jobRole || '').toLowerCase())) score += 15;
    if (legacyCareerSignals.has((alumni.company || '').toLowerCase())) score += 10;
    if (userData.department && alumni.department && userData.department === alumni.department) {
      score += 10;
    }
    if (resumeMissing.size > 0) {
      const bridging = intersectionCount(resumeMissing, alumniSkills);
      score += Math.min(12, bridging * 4);
    }
    score = Math.min(100, score);
    if (score < 45) continue;

    mentorRecommendations.push({
      id: `mentor_${alumni.id || alumni.uid}`,
      userId,
      type: 'mentor',
      priority: score >= 75 ? 'high' : 'medium',
      title: `Connect with ${(alumni.personal && (alumni.personal.displayName || alumni.personal.fullName)) || 'Mentor'}`,
      description: `${alumni.jobRole || 'Alumni mentor'} at ${alumni.company || 'CampusConnect Network'}`,
      score,
      isActive: true,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      source: 'mentor',
      metadata: {
        alumniId: alumni.id || alumni.uid,
        company: alumni.company || null,
        jobRole: alumni.jobRole || null,
      },
    });
  }
  mentorRecommendations.sort((a, b) => b.score - a.score);

  const jobRecommendations = [];
  for (const opportunity of opportunityDocs) {
    if (!opportunity) continue;
    const opportunitySkills = normalizeTokens(opportunity.skills || []);
    let score = intersectionCount(studentSkills, opportunitySkills) * 20;

    const titleTokens = normalizeTokens([opportunity.title || '', opportunity.company || '']);
    score += intersectionCount(legacyCareerSignals, titleTokens) * 12;

    const missingForRole = intersectionCount(resumeMissing, opportunitySkills);
    score += Math.max(0, 10 - missingForRole * 2);
    score = Math.min(100, score);

    if (score < 40) continue;

    jobRecommendations.push({
      id: `job_${opportunity.id}`,
      userId,
      type: 'job',
      priority: score >= 70 ? 'high' : 'medium',
      title: `${opportunity.title || 'Opportunity'} at ${opportunity.company || 'Company'}`,
      description: `AI match score: ${score}%`,
      score,
      isActive: true,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      source: 'opportunity',
      opportunityId: opportunity.id,
      metadata: {opportunityId: opportunity.id},
    });
  }
  jobRecommendations.sort((a, b) => b.score - a.score);

  return {
    mentor: mentorRecommendations.slice(0, 4),
    job: jobRecommendations.slice(0, 4),
    nudge: _buildNudgeRecommendation(u, userId),
  };
}

// ============================================================
// TOP-LEVEL ENTRY
// ============================================================

/**
 * Build the complete recommendation list for a student.
 *
 * @param {object} params
 * @param {string} params.userId
 * @param {object} params.userData - Raw user document
 * @param {object} params.options - {resumeData} passthrough
 * @param {Array<object>} params.alumniDocs - Alumni candidates (limit 120)
 * @param {Array<object>} params.opportunityDocs - Active opportunities
 * @param {Array<object>} params.placementDocs - Active placements
 * @param {Set<string>} params.appliedPlacementIds - Placement ids already applied
 * @returns {{recommendations: Array<object>, summary: object}}
 */
function buildRecommendations({
  userId,
  userData,
  options = {},
  alumniDocs = [],
  opportunityDocs = [],
  placementDocs = [],
  appliedPlacementIds = new Set(),
}) {
  const portfolio = extractPortfolio(userData);
  const u = extractUserSignals(userData, portfolio, options);

  // v8.9.1 portfolio-first: when the student has NO demonstrable portfolio
  // evidence, every personalized emitter is gated off internally —
  // roleRecs/placementRecs/legacy.mentor/legacy.job are all empty, and ONLY
  // the portfolio gate card + the generic nudge are emitted.
  //
  // v9.0 (Phase 2): skill-gap rows are no longer produced — the AI Career
  // Coach owns career reasoning. Skill signals still surface on role /
  // placement cards as `skillsMissing` metadata; no `skill_*` documents.
  const legacy = buildLegacyRecommendations(userData, u, alumniDocs, opportunityDocs, userId);
  const roleRecs = buildRoleRecommendations(u, userId);
  const placementRecs = buildPlacementRecommendations(placementDocs, u, appliedPlacementIds, userId);
  const portfolioGateRecs = buildPortfolioGateRecommendations(u, userId);

  const recommendations = [
    ...portfolioGateRecs,
    ...roleRecs,
    ...placementRecs,
    ...legacy.mentor,
    ...legacy.job,
    legacy.nudge,
  ];

  return {
    recommendations,
    summary: {
      roleMatches: roleRecs.length,
      placementMatches: placementRecs.length,
      mentorMatches: legacy.mentor.length,
      jobMatches: legacy.job.length,
      portfolioGate: portfolioGateRecs.length,
    },
  };
}

module.exports = {
  buildRecommendations,
  buildPortfolioGateRecommendations,
  checkMandatoryEligibility,
  classifyPlacementMatch,
  extractPortfolio,
  extractUserSignals,
};
