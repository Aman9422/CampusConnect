# CampusConnect v9.0 — Intelligence Ecosystem Integration, Security & Scale

## Objective

Build on the completed **v8.9 AI Recommendation & Career Intelligence** release.

v9.0 should unify:

**Student Profile + Resume/ATS + Skills + Projects + Career Preferences + Placements + AI → one Career Intelligence ecosystem**

Do not create a second recommendation engine or redesign the architecture.

---

## 1. Unified Recommendation Intelligence

Audit and unify:

* `refreshRecommendations`
* `RecommendationService`
* AI Career Coach
* Career-role matching
* Skill-gap recommendations
* Placement recommendations
* Dashboard recommendations
* Teacher recommendation insights

Use **one recommendation source of truth**.

Architecture:

```text
Student Data
   ↓
Career Intelligence
   ↓
Recommendation Engine
   ↓
Dashboard / Career Coach / Placement / Teacher Insights
```

Dashboard should show a concise summary; AI Career Coach should provide detailed analysis.

---

## 2. Recommendation Quality

Use real student signals:

* Skills
* Projects
* Experience
* Career preferences
* Resume/ATS
* Certifications
* Opportunities

Fix:

* repeated/fake percentages
* inconsistent role-fit scores
* generic explanations
* incorrect recommendation ranking

Every recommendation must answer:

**Why am I seeing this?**

Do not invent skills or achievements.

---

## 3. Career & Placement Intelligence

Implement/strengthen:

* Career-role matching
* Skill-gap detection
* Resume → Skills → Opportunities relationship
* Personalized placement recommendations
* Strong Match / Potential Match / Skill Gap

Mandatory placement eligibility remains **deterministic** and cannot be overridden by AI.

---

## 4. Recommendation Actions

Audit all CTAs.

Examples:

* Project → **Add Project**
* Resume → **Improve Resume / Resume Review**
* Interview → **Prepare with AI**
* Placement → **View Opportunity**

Do not use generic or misleading actions such as "Open Portfolio" when a more specific action exists.

---

## 5. Teacher Intelligence + Teacher Profile

Add recommendation insights to Teacher Intelligence:

* career goals
* target roles
* common skill gaps
* placement-match trends
* department trends

Also fix the reported **Teacher Profile using Student Profile UI**.

Ensure:

```text
Student → Student Profile
Alumni  → Lightweight Alumni Profile
Teacher → Teacher Profile
```

Teacher profile must not show Student Portfolio/Resume/Career controls.

Preserve role ownership/security.

---

## 6. AI Integration

Use existing v8.8 infrastructure:

```text
Groq → GPT-OSS 20B
        ↓ failure
Hugging Face → GPT-OSS 20B
```

Preserve:

* fallback
* timeouts
* structured responses
* server-side API keys
* quota architecture

Recommendation generation must not consume Resume Review quota.

---

## 7. AI Prompt/Input Security

Add appropriate input sanitization:

* control-character handling
* input-length limits
* prompt boundaries
* treat user content as data, not instructions

Do not break valid resume text, URLs, Markdown, or code.

---

## 8. Unified AI Quotas

Audit:

* `ai_usage`
* `resume_usage`
* `career_coach_usage`
* `users/{uid}.aiUsageCount`

Design a safe migration toward:

```text
user_ai_quotas/{uid}
```

with nested feature quotas where practical.

Preserve all existing limits, reservations, rollback behavior, and backward compatibility.

---

## 9. App Check

Evaluate and implement Firebase App Check:

* Android → Play Integrity
* iOS → DeviceCheck
* Web → reCAPTCHA v3

Do not weaken Firebase Auth/Firestore/Storage rules.

Document development/debug and production enforcement behavior.

---

## 10. Scalability

### Pagination

Audit large queries, especially:

`refreshRecommendationsForStudent`

and engagement recomputation.

Use cursor-based pagination where needed.

### Engagement

Evaluate materialized aggregates such as:

* `totalPoints`
* `lastActiveAt`
* `dailyStreak`

Reduce repeated historical activity scans while preserving correctness/idempotency.

### Career Coach

Verify the required `pendingSince` index. Use a composite index only if actually required.

---

## 11. Scheduler & Cost Optimization

Audit the current scheduled jobs:

* `autoExpireOpportunities`
* `cleanupExpiredAIConversations`
* `compensateStaleAIAnalysisQuota`
* `compensateStaleCareerCoachQuota`
* `compensateStaleResumeQuota`
* `recomputeEngagementScores`
* `sendInactivityReminders`

Determine:

* current Scheduler count/cost
* Firestore reads/writes
* scalability at 100 / 1,000 / 10,000 students
* overlapping work
* opportunities for query/frequency/batch optimization
* whether compatible jobs can safely be consolidated

Do not delete Scheduler jobs blindly or manually from the Console.

Optimize for **cost + scalability + reliability**, not cost alone.

---

## 12. Legacy AI Conversations

Continue supporting:

```text
users/{uid}/ai_interactions
ai_conversations
```

until dependency/data-expiry checks confirm the legacy collection can be retired.

Then safely stop new legacy writes and remove dead compatibility code.

Do not delete legacy data prematurely.

---

## 13. Security & Testing

Audit:

* Firestore rules
* Storage rules
* Callable authentication
* App Check
* recommendation ownership
* role isolation
* quota ownership
* profile ownership

Add tests for:

* recommendation consistency
* score/ranking
* skill gaps
* placement eligibility
* Teacher Profile
* AI input security
* quota behavior
* App Check configuration
* pagination
* engagement aggregation
* AI chat cleanup
* Scheduler batching/idempotency

---

## 14. Validation

Run:

```text id="2nmk8z"
flutter analyze
flutter test
node --check functions/index.js
dart format
```

Also validate all changed JavaScript files.

Confirm:

* no analyzer errors/warnings
* all tests pass
* no duplicate recommendation writers
* no API keys exposed
* no unintended bulk reads
* no security regressions
* no duplicate quota charging

---

## 15. Manual Testing

### Student

* Dashboard recommendations
* AI Career Coach
* Role matches
* Skill gaps
* Placement matches
* Recommendation explanations
* Correct CTAs
* Resume/ATS integration

### Teacher

* Teacher Dashboard
* Teacher Profile
* Teacher intelligence
* No Student Profile leakage
* No private resume leakage

### Alumni

* Lightweight profile
* Text Resume Review
* Alumni Community Chat
* No Portfolio requirement

### AI

* Normal AI chat
* Provider fallback
* ATS/recommendation outputs
* Quota behavior

### Security/Scale

* Cross-user access denied
* App Check behavior
* Pagination
* Scheduled maintenance

---

## 16. Documentation & Version

Update:

* `docs/todo.md`
* `docs/issues.md`
* `docs/v8_workspace_tracker.md`
* `docs/confirmation.md`
* `docs/Task.md`
* `pubspec.yaml`

Document the final:

* intelligence architecture
* scoring
* role matching
* App Check
* quotas
* pagination
* engagement aggregates
* legacy migration
* Scheduler optimization
* security
* testing
* deployment
* known limitations

Version:

**v9.0.0**

### Important Constraints

* No second recommendation engine
* No second AI/ATS pipeline
* No Alumni Portfolio restoration
* No API keys in Flutter
* No AI override of deterministic eligibility/security
* No destructive quota migration
* No premature legacy data deletion
* No unnecessary Scheduler consolidation
* Preserve v8.8 AI provider/fallback architecture
* Preserve placement/resume snapshots
* Preserve role-specific Student/Alumni/Teacher experiences
