# Eligibility Rules — Shared Reference

> **Purpose:** Document the eligibility rules that are implemented identically on
> the client (`EligibilityEngine`) and server (`checkMandatoryEligibility`).
> Both MUST stay in sync — update this file AND both implementations together.

---

## Canonical Rule Set

The following rules are checked in order. A student must pass **ALL** rules to
be eligible for a placement. The first failing rule short-circuits (no further
checks are run).

| # | Rule | Field(s) | Client Source | Server Source |
|---|------|----------|---------------|---------------|
| 1 | **Deadline** | `placement.deadline` | `EligibilityEngine.checkEligibility` | `checkMandatoryEligibility` |
| 2 | **Already applied** | `appliedPlacementIds` | `hasApplied` parameter | `appliedIds.has(placement.id)` |
| 3 | **CGPA minimum** | `placement.requirements.minCgpa` | `profile.academic.cgpa >= minCgpa` | `u.cgpa < minCgpa` → fail |
| 4 | **Allowed years** | `placement.requirements.allowedYears` | `allowedYears.contains(userYear)` | `allowedYears.includes(u.year)` |
| 5 | **Program/branch** | `placement.requirements.programs` / `.branches` | `programs.any(p == userProgram)` | `programs.includes(u.program)` |

### Notes

- **Rules 3–5** only fire when the requirement is specified (non-null / non-empty).
  If no structured requirements exist, the placement is "open to all".
- **Branches** (rule 5) are only checked when `programs` is empty but `branches`
  is specified (separate requirement set).
- The server uses `.toUpperCase()` normalization for program comparison. The
  client also normalizes to uppercase.
- Skills / career preferences are **NOT** hard gates — they only affect scoring
  and match tier classification (determined by the recommendation engine, not
  by eligibility).

---

## Authoritative Implementations

| File | Function | Language | Role |
|------|----------|----------|------|
| `lib/services/eligibility_engine.dart` | `EligibilityEngine.checkEligibility()` | Dart | **Client-side UX** — shows eligibility badges before server runs |
| `functions/recommendations/engine.js` | `checkMandatoryEligibility()` | Node.js | **Server-side authority** — final decision, never AI-overridable |

---

## Sync Policy

When modifying eligibility rules:

1. Update `docs/eligibility_rules.md` (this file) with the new rule
2. Update `lib/services/eligibility_engine.dart` (client)
3. Update `functions/recommendations/engine.js` (server)
4. Run `flutter test` (client)
5. Run `node --check functions/recommendations/engine.js` (server syntax)

The server is **authoritative**. The client duplicates rules for UX purposes
(showing eligibility badges in the UI before the recommendation engine runs).
If the client and server disagree, the server's decision wins.
