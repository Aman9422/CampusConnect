/**
 * v9.2 audit (BUG-11) — recommendation engine role-card suppression.
 *
 * Regression guard for the "Career match: <other role>" noise: once a student
 * has DECLARED a career interest that maps to a known role, the engine must
 * emit ZERO `type: 'role'` cards (they have already chosen a path). A student
 * who has NOT declared an interest must still receive discovery role cards.
 *
 * Pure-function test — no Firestore, no emulator, no fakes.
 */

const test = require('node:test');
const assert = require('node:assert');

const {
  buildRecommendations,
  isDeclaredRole,
} = require('../recommendations/engine');

/** A profile with REAL portfolio evidence (skills + a project). */
function userWithEvidence({careerInterest} = {}) {
  const skills = ['flutter', 'dart', 'firebase', 'rest api', 'git'];
  return {
    role: 'student',
    career: careerInterest ? {careerInterest} : {},
    // Root-level skills are read by extractUserSignals; the portfolio mirror
    // is what real students carry.
    skills,
    portfolio: {
      skills,
      projects: [
        {title: 'Campus App', technologies: ['flutter', 'dart', 'firebase']},
      ],
    },
  };
}

function roleCardsFor(userData) {
  const {recommendations} = buildRecommendations({
    userId: 'u_test',
    userData,
  });
  return recommendations.filter((r) => r.type === 'role');
}

test('BUG-11: a DECLARED career interest emits zero role cards', () => {
  // "App Development" maps to the mobile_developer role.
  const userData = userWithEvidence({careerInterest: 'App Development'});
  const roleCards = roleCardsFor(userData);

  assert.strictEqual(
      roleCards.length,
      0,
      'a student who declared a career interest must not be re-offered ' +
      `career-match cards, got: ${roleCards.map((r) => r.title).join(', ')}`,
  );
});

test('BUG-11: an UNDECLARED profile still gets discovery role cards', () => {
  // No career interest at all — role discovery must still fire (evidence
  // present via skills + project), so the section is not permanently empty.
  const userData = userWithEvidence();
  const roleCards = roleCardsFor(userData);

  assert.ok(
      roleCards.length > 0,
      'an undeclared profile with portfolio evidence should still receive ' +
      'discovery role cards',
  );
  // Cards, when present, carry the canonical title prefix.
  for (const card of roleCards) {
    assert.match(card.title, /^Career match: /);
  }
});

test('BUG-11: isDeclaredRole is exact-phrase/token based (no false positives)', () => {
  const {extractUserSignals, extractPortfolio} =
      require('../recommendations/engine');
  const {CAREER_ROLES} = require('../recommendations/career_roles');

  const appUser = userWithEvidence({careerInterest: 'App Development'});
  const appSignals = extractUserSignals(appUser, extractPortfolio(appUser));

  const webRole = CAREER_ROLES.find((r) => r.id === 'web_developer');
  const mobileRole = CAREER_ROLES.find((r) => r.id === 'mobile_developer');

  if (mobileRole) {
    assert.strictEqual(
        isDeclaredRole(mobileRole, appSignals),
        true,
        'App Development must claim the mobile-developer role',
    );
  }
  if (webRole) {
    assert.strictEqual(
        isDeclaredRole(webRole, appSignals),
        false,
        'App Development must NOT claim the unrelated web-developer role',
    );
  }
});
