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
| 5 | **Program/branch** (alternatives) | `placement.requirements.programs` / `.branches` | `programs.any(p == userProgram)` | `programs.includes(u.program)` |

### Notes

- **Rules 3–5** only fire when the requirement is specified (non-null / non-empty).
  If no structured requirements exist, the placement is "open to all".
- **Rule 5 — `programs` and `branches` are ALTERNATIVES, not two requirements.**
  The server evaluates them with an `else if`:

  ```js
  if (programs.length > 0 && !programs.includes(u.program)) {
    failures.push(`Program ${u.program || '—'} not eligible`);
  } else if (branches.length > 0 && !branches.includes(u.program)) {
    failures.push('Branch not eligible');
  }
  ```

  Consequences that both implementations MUST reproduce:

  | `programs` | `branches` | What is evaluated |
  |---|---|---|
  | non-empty | anything | **only** `programs`; `branches` is ignored entirely |
  | empty | non-empty | **only** `branches` |
  | empty | empty | nothing (no program/branch gate) |

  Both lists are compared against the student's **program**
  (`profile.academic.program` client-side, `u.program` server-side) — a student
  has one program string, and `branches` is matched against that same value.
  A placement that lists **both** fields is therefore judged on `programs`
  alone; a student matching only `branches` is **not** eligible for it.
  A missing student program yields `''`, which matches neither list.
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

---

## Change log

### v9.2.4 — rule 5 client/server divergence fixed (audit finding D-3)

Before v9.2.4 the client (`EligibilityEngine.checkEligibility`) evaluated
`programs` and `branches` as **two independent requirements** — both had to
pass — while the server evaluated them as **alternatives** (`else if`). For a
placement specifying both, a student whose program matched but whose branch did
not was shown **"not eligible"** in the UI while the server considered them
eligible and emitted a placement recommendation, and the reverse case was
possible too.

v9.2.4 aligns the client to the server's `else if` semantics, so the badge, the
recommendation engine and this document now agree. Regression coverage:
`test/eligibility_parity_test.dart` (table-driven, drives the real
`EligibilityEngine` against a mirror of `checkMandatoryEligibility`).
