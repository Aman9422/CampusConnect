a new issue came:-
it still showing same soc tcs and softwre enginerr still comming and i want to ask where does it take knowledge of the domain does it take it from the start profile or portfolio or when i create a new account after verification it first popup the complete your profile in there is last option about carrer options or somthing like that which is in option cant make it required file and get the knowledge about the students domain and in recommendation system ask them to complete the portfolio first then using the portfolio data and ai cant we recommend what necessary or required for student

---

## v8.9.1 — RESOLVED (2026-08-16)

> Status: **IMPLEMENTED + VALIDATED (294/294 tests) + ✅ DEPLOYED (2026-08-16 — `firebase deploy --only functions` SUCCESS, 18/18 functions updated: `refreshRecommendations`, `onProfileUpdatedRefreshAI`, `onResumeReviewCreatedRefreshMatches` now enforce the portfolio-first contract in production)**

### Answers to the user's 3 questions

1. **Where does the recommendation system take knowledge of the student's domain?**
   - `functions/recommendations/engine.js` → `extractUserSignals` merges TWO sources:
     - **Profile (stated intent)**: root `skills`, `careerInterest`, `department`, `graduationYear`, `academic`.
     - **Portfolio (demonstrated evidence)**: `userData.portfolio` — skills, projects+tech, certifications, experience, languages, `preferences.preferredRoles` / `careerObjective`, and `resume.latestATSScore`.
   - Career Interest is a *stated intent* signal; portfolio data is *demonstrated evidence*. The engine uses intent for ranking alignment once evidence exists — evidence is what unlocks recommendations (see below).

2. **Career options can't be skipped / they should be required:**
   - `Career Interest` is already **REQUIRED** (validator) both in `lib/views/profile_setup_view.dart` (the post-verification "Complete your profile" popup) and in `lib/views/edit_profile_view.dart` (v8.9.1 added it there too). Students cannot complete setup without choosing a career interest.
   - `Skills` is optional at setup but is now the KEY to unlocking recommendations — see the portfolio-first contract.

3. **Complete portfolio first → then recommend what is necessary/required for the student:**
   - **NEW v8.9.1 portfolio-first contract** in the engine — every personalized recommendation type (`role`, `placement`, `skill`, `mentor`, `job`) is gated behind `hasMeaningfulPortfolioContent` (demonstrated skills ∪ project technologies ∪ ATS-scored resume).
   - A student with ONLY a career interest (no portfolio evidence) now receives **exactly one card**: `portfolio` — "Complete your portfolio first" (routes to the portfolio builder). NO more "Software Engineer" role cards, NO more SOC/TCS placement cards, NO legacy job/mentor noise.
   - Once the student adds skills, projects or a resume/ATS score, the gate card disappears and the engine emits real, personalized role/placement/skill-gap (+ mentor/job) recommendations.
   - The TCS/SOC noise is doubly filtered: the relevance gate drops any eligible placement with zero skill overlap AND zero career alignment; the portfolio-first gate stops placement matching entirely for intent-only students.

### Changes
- `functions/recommendations/engine.js` — `hasMeaningfulPortfolioContent` flag; placement + role + legacy(mentor/job) emitters gated; portfolio-gate card consolidated on the single flag; `description`/`reason` copy updated.
- `test/placement_match_test.dart` — portfolio-first gate + relevance gate mirrored; TCS SOC regression test; intent-only student test; evidence-student test.
- `docs/todo.md`, `docs/issues.md`, `docs/think.md`, `docs/confirmation.md`, `docs/v8_workspace_tracker.md` — v8.9.1 sections.
- `pubspec.yaml` → **8.9.1+93**.

---

## v8.9.2 — RESOLVED (2026-08-16)

> Issue: "No New Recommendations After Filling Portfolio (80% Strength)" — `project_info__25.md` / `project_info__26.md` (identical investigation reports).
> Status: **IMPLEMENTED + VALIDATED (302/302 tests) — client fix. NO `firebase deploy` REQUIRED for this release (no `functions/` or `firestore.rules` changes in v8.9.2).**

### What actually happened

The v8.9.1 portfolio-first engine was working **correctly**. The failure was a **client-side data-persistence gap** that made the server see an empty document:

- The logged-in user's Firestore doc (`users/{uid}`) held only `(metadata, role, personal.email)` — no `portfolio`, no `academic`, no `career`, no `skills`, no `profileCompleted`.
- The app UI showed 80% portfolio strength because it renders from **memory/SharedPreferences cache**, not from Firestore.
- `functions/recommendations/engine.js` computes `hasMeaningfulPortfolioContent` from **Firestore** (`userData.portfolio`). It read nothing → it correctly emitted ONLY the "Complete your portfolio first" gate card and deleted stale cards on every refresh.
- Result: the user's 80% portfolio was invisible to the recommendation engine — "no new recommendations after filling portfolio" because the server never saw the portfolio.

### Root causes (confirmed in code)

1. **`ProfileService.createProfile` — the ONLY non-merge `set()` on `users/{uid}` in the codebase.** Its `else` branch did `docRef.set(profile.toFirestore())` with NO `SetOptions(merge: true)`. A non-merge `set()` **replaces the entire document**. If that branch ever executed against a doc that already existed (a race with `updateUserRole`, a stale `profileExists` read, or a re-init after logout/re-login) it permanently wiped the student's profile AND portfolio — leaving exactly the observed empty shell `(metadata, role, personal.email)`. (`project_info__14.md` Finding 4 candidate B predicted this exact mechanism.)
2. **The v8.4.4 stale-guards silently hid the wipe.** The guards correctly ignore EMPTY server events so a local-cache replay can't wipe a just-uploaded resume — but that same protection also ignored a **genuinely** empty server document. Memory/cache kept showing 80% strength with no warning, so the divergence was invisible.
3. **`savePortfolio`'s diff-based writes cannot rebuild a wiped doc.** When memory has data and the server is empty, `previous != null` → the service writes only *changed* sections. With an empty (null) server portfolio, no section is recognized as "changed" → nothing gets written.

### Fixes (v8.9.2)

| # | File | Change |
|---|---|---|
| 1 | `lib/services/firestore/profile_service.dart` | `createProfile` now writes **both** branches with `SetOptions(merge: true)` — the full user document can never be destroyed by this path again. merge creates the doc when missing and only fills missing fields when present. |
| 2 | `lib/providers/portfolio_provider.dart` | **Divergence detection + self-heal.** New flag `_serverNonEmpty` distinguishes "empty event = stale cache replay" (v8.4.4 behavior, preserved) from "server document genuinely empty after having confirmed content" (wiped doc). On divergence, the provider surfaces a warning banner and **automatically re-saves the full portfolio** (full non-diff write) so the engine's evidence gate can unlock. Restore is attempted at most once per divergence (no infinite write loop) and is bounded by the existing 20 s save timeout; a failure never clears in-memory data. |
| 3 | `lib/providers/portfolio_provider.dart` | New getters `isServerSynced` + `restoreMessage` expose the divergence to the UI. |
| 4 | `lib/providers/portfolio_provider.dart` | Extracted the shared divergence rule into `@visibleForTesting bool shouldTriggerPortfolioRestore(...)`, used by both the stream listener and `refresh()`. |
| 5 | `lib/views/dashboards/student_dashboard_view.dart` | Warning banner under the Resume Summary Card when the server doc is empty — explains why recommendations are still gated despite 80% strength. Restore is automatic; on failure the message instructs re-saving from Edit Portfolio. |
| 6 | `lib/views/portfolio/student_portfolio_screen.dart` | Same warning banner on the portfolio screen (after the completion header), via a `_buildSyncWarning` helper. |
| 7 | `test/portfolio_sync_state_test.dart` | **NEW regression suite (8 tests)** — pins the divergence rule + sync-state banner condition: v8.4.4 stale-guard preserved (no restore on the first empty event), restore triggers only after the server confirmed content, no double-restore loop, fresh-user = synced, and the exact bug state (memory has data, server never confirmed) renders as NOT synced. |

### Validation
- `flutter analyze` — **0 errors / 0 warnings** (76 pre-existing info lints, none in v8.9.2 files).
- `flutter test` — **302/302 passed** (294 existing + 8 new sync-state regression tests).
- `node --check` on `functions/index.js`, `functions/recommendations/engine.js`, `functions/recommendations/ai_explanations.js`, `functions/ai/aiProvider.js` — all clean (no server changes).
- `pubspec.yaml` → **8.9.2+94**.

### How the user's state is healed
On the next app launch/login + refresh + portfolio screen visit, the provider detects the empty server doc while memory/cache holds the 80% portfolio, shows the restore banner, and **writes the portfolio back to Firestore** in one full non-diff save. The `onProfileUpdatedRefreshAI` trigger then recomputes recommendations from the now-visible portfolio evidence, and the "Complete your portfolio first" gate card is replaced with real personalized recommendations.
