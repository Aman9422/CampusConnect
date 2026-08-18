# AI Career Coach — Replace Static Skill-Gap Engine with AI-Powered Career Guidance

**Version:** v9.0 (career-coach)
**Status:** Spec — implementation pending approval
**Scope:** Student dashboard recommendation system

---

## 1. Objective

Transform the current **"Skill Gap Recommendations"** feature (the deterministic
`skill_*` rows produced in `functions/recommendations/engine.js`) into an
**AI-powered "Career Coach"** system.

The AI analyzes the student's complete available career data and decides what the
student should focus on next. It must **NOT** simply compare the student's skills
against a static role skill list.

**Core architectural principle:** the deterministic engine is useful only for
extracting/validating factual profile data. It is **NOT** responsible for deciding
what career action a student needs. The core intelligence comes from the existing
AI provider architecture (Groq → HuggingFace fallback), cost-controlled and cached
so we never call the model on every dashboard refresh.

### 1.1 Anti-pattern (must NOT happen)

A Flutter/Dart/Firebase student with multiple Flutter projects and mobile
experience must **NOT** automatically receive:

- "Learn Kotlin"
- "Learn Swift"
- "Learn Android"

…merely because those technologies appear in a generic Mobile Developer
requirement list.

The AI must instead reason about whether the student should:

- deepen an existing skill
- build a stronger project
- deploy an existing application
- improve their resume
- improve ATS keywords
- gain relevant experience
- add a certification
- improve their portfolio
- prepare for interviews
- learn a genuinely important missing skill
- or take another career-relevant action

The system prioritizes **ACTIONABLE career development** over recommending
additional technology tags.

---

## 2. Data the AI May Consider

The AI analyzes the student's complete available career data:

- Student profile
- Career goal / target role
- Current year / semester
- Skills
- Projects
- Project technologies
- Experience
- Certifications
- Achievements
- Resume data
- ATS score, if available
- Portfolio completeness
- Existing resume reviews
- Existing career preferences
- Existing role/placement data, where available

---

## 3. PHASE 1 — Fix the Existing Routing Bug

In `lib/views/dashboards/student_dashboard_view.dart`, the current card tap
handler is WRONG:

```dart
case RecommendationType.skill:
  Navigator.pushNamed(context, profileSetupRoute);   // WRONG
case RecommendationType.role:
  Navigator.pushNamed(context, profileSetupRoute);   // WRONG
```

`profileSetupRoute` is the first-run onboarding/setup screen. It **must NEVER** be
opened from an existing student's recommendation card.

Fix immediately. Skill, role, and future career-coaching cards navigate to
appropriate existing destinations:

| Recommendation | Destination |
|---|---|
| Profile-related actions | Edit Profile → Career & Skills |
| Resume actions | Resume Review / Resume upload |
| Portfolio actions | Student Portfolio screen |
| Project actions | Projects manager |
| Certification / Experience / Achievement actions | Respective manager screens |

If no appropriate destination exists, create a dedicated action/detail screen.
Do NOT break the first-time onboarding flow (`ProfileSetupView` stays reserved
for `AuthGuard`).

---

## 4. PHASE 2 — Remove the Fake 66% Score

The current skill-gap scoring:

```js
score: Math.min(100, 50 + entry.count * 8)
```

produces misleading identical scores (Swift 66%, Android 66%, Kotlin 66%, iOS 66%).
This is NOT a meaningful match score.

- Remove this presentation entirely.
- Do **NOT** replace it with another fabricated percentage.
- The AI provides meaningful metadata instead: `priority` (high/medium/low),
  `impact` (high/medium/low), and/or a simple ranked order.
- If a numerical score is ever required later, it must have a real, explainable
  meaning — never fabricated from arbitrary constants.

---

## 5. PHASE 3 — AI Is the Career-Reasoning Layer

Use the existing AI provider/service architecture, same philosophy as Resume Review:

- Primary: **Groq**
- Fallback: **HuggingFace**
- Reuse `functions/ai/aiProvider.js` (`callAIProvider`, `extractJSON`,
  `normalizeAIResponse` patterns). Do NOT create a separate AI client.

The deterministic code handles ONLY things that should be deterministic:

- collecting student data
- checking whether data exists
- normalizing data
- preventing duplicate recommendations
- validating AI output
- enforcing supported recommendation types
- enforcing usage limits
- caching
- detecting when analysis is stale
- routing / navigation
- UI rendering

Do NOT encode hundreds of career rules into `engine.js`. **The AI determines the
actual career recommendations.**

---

## 6. PHASE 4 — Structured AI Response

The AI returns **structured JSON**, not arbitrary prose displayed directly.

```json
{
  "careerReadiness": {
    "level": "strong",
    "summary": "..."
  },
  "careerFocus": "...",
  "recommendations": [
    {
      "type": "portfolio",
      "priority": "high",
      "title": "...",
      "reason": "...",
      "action": "...",
      "whyItMatters": "...",
      "estimatedEffort": "..."
    }
  ]
}
```

- Use ONLY recommendation types the application actually supports.
- The response MUST be validated before display.
- Malformed JSON / invalid types / missing required fields / unusable content →
  gracefully fall back to a safe state. Never crash the dashboard.

---

## 7. PHASE 5 — Prompt Rules

The AI prompt must explicitly include:

1. NEVER recommend a skill the student already has.
2. Do not recommend a technology merely because it appears in a generic role
   requirement.
3. Consider the student's EXISTING STACK before recommending a new technology.
4. Prefer strengthening existing relevant skills when that provides more career
   value than learning an unrelated technology.
5. Consider the student's year/semester (as context, not rigid rules):
   - early-year → fundamentals, projects, exploration
   - middle-year → stronger projects, internships, specialization
   - final-year → placement preparation, resume, interviews, portfolio quality,
     job readiness
6. Consider project QUALITY, not just project count.
7. Consider experience and certifications.
8. Consider resume/ATS information when available.
9. Consider the target role / career goal.
10. Recommendations must be realistically achievable.
11. Return ~3–5 HIGH-VALUE recommendations — never 10–20.
12. Prioritize recommendations.
13. If the student is already strong in an area, say so explicitly instead of
    recommending unnecessary learning.
14. The AI is allowed to say: *"No new skill is necessary right now. Focus on
    building/deploying/improving your existing projects."*

---

## 8. PHASE 6 — Example Behavior

**Student:** Target = Mobile App Developer, 3rd year, skills = Flutter/Dart/
Firebase/Git, 2 Flutter apps, Mobile Dev Intern, Flutter cert, ATS 78.

**BAD (current):** `+ Kotlin 66%`, `+ Swift 66%`, `+ Android 66%`

**GOOD:**

1. **Strengthen Portfolio — HIGH** — Your Flutter experience is relevant to your
   target role. Instead of adding another language, build one production-quality
   app demonstrating auth, cloud integration, error handling, offline support,
   notifications, and deployment.
2. **Improve Resume ATS — MEDIUM** — Your resume could better communicate your
   mobile development experience and relevant technical keywords.
3. **Strengthen Android Deployment — MEDIUM** — Add a properly deployed Android
   app as end-to-end evidence.

Kotlin/Swift are NOT automatically recommended.

---

## 9. PHASE 7 — "Improve Your Portfolio" Recommendations

Add a portfolio-improvement recommendation category. Possible actions the AI may
choose from (it decides which matter for the individual student — not hardcoded
advice):

- Resume missing → upload/create resume
- ATS score low → improve resume
- Too few projects → build/add project
- Projects lack descriptions → improve project descriptions
- Projects lack technologies → improve project metadata
- No experience → focus on internship/experience opportunities
- Weak portfolio evidence → strengthen projects
- Missing certifications → consider relevant certification
- Missing achievements → add relevant achievements
- Missing career goal → complete career preferences

---

## 10. PHASE 8 — Cost Control / Caching

**DO NOT call the AI on every dashboard open/rebuild.**

Flow:

```
Student opens dashboard
  → check cached Career Coach analysis
  → valid? → display cached analysis
  → missing/stale? → AI request
  → validate response
  → save analysis
  → display analysis
```

Metadata stored: `generatedAt`, `profileDataVersion` (fingerprint of meaningful
career data), `analysisVersion`, usage count.

Regenerate ONLY when meaningful career data changes OR the student explicitly
requests "Re-analyze". Meaningful changes:

- skills changed
- career goal changed
- projects changed
- experience changed
- certifications changed
- resume changed
- ATS score changed
- portfolio changed

Never regenerate because the dashboard widget rebuilt.

---

## 11. PHASE 9 — Usage Limit

Follow the existing Resume Review usage-control pattern
(`resume_usage/{uid}`, transactional quota consumption, rollback on AI failure).

- Configurable `careerCoachMonthlyLimit` (reuse existing configurable AI usage
  patterns where appropriate — do not hardcode if the project has a
  configurable system).
- UI should eventually show: **"Career Coach — N analyses remaining this month"**.
- No API keys / provider credentials reach the Flutter client. All AI calls go
  through the secure backend Cloud Function.

---

## 12. PHASE 10 — Data Privacy / Prompt Size

Do not blindly send unnecessary Firestore data to the AI. Build a normalized
`CareerAnalysisInput` object:

```json
{
  "careerGoal": "...",
  "academicYear": "...",
  "skills": [],
  "projects": [],
  "experience": [],
  "certifications": [],
  "achievements": [],
  "resumeSummary": "...",
  "atsScore": 78,
  "portfolioSummary": "..."
}
```

Avoid sending: passwords, auth tokens, internal IDs (unless required),
unrelated personal information, unnecessary Firestore metadata. Resume text is
sent only as needed for career analysis.

---

## 13. PHASE 11 — UI Design

Rename/reframe the dashboard section from "Skill Gap Recommendations" to
**"AI Career Coach"**. Career guidance, not a checklist.

### 13.1 Dashboard ↔ Full-Screen Architecture (approved)

**STUDENT DASHBOARD — `Recommended for You` (stays on the main dashboard):**
- Concise **"What should I do next?"** surface.
- Shows ONLY the **2–3 highest-priority** recommendations (sorted by the AI's
  `priority` field; existing order, sliced). Never more.
- Each compact card shows: priority, concise title, 1–2 line explanation,
  a short recommended action, and one CTA button.
- At the bottom: **"View all recommendations →"** → navigates to
  `/career-coach`.
- If fewer than 2–3 valid recommendations exist, show only what exists.
  Never fabricate recommendations.
- No Career Coach analysis yet → empty/loading state with a "Generate
  analysis" action.
- The dashboard REFRESH icon must NOT trigger a new AI request — refreshing
  reads the cached analysis only (no quota consumption).
- The old "Learn: Swift / iOS", "66%", "Missing skill · 2 signals", "+ Swift"
  cards DISAPPEAR entirely.

**CAREER COACH SCREEN — `/career-coach` (full analysis):**
- Career readiness level + summary
- Career focus
- ALL AI recommendations (priority, detailed reasoning, recommended action,
  why it matters, estimated effort)
- Re-analyze button
- Remaining analyses / usage counter ("N analyses remaining this month")

### 13.2 Card Examples (content comes from the AI analysis)

```
BAD:  + Learn Kotlin

GOOD: 🎯 Strengthen Your Mobile Portfolio — High Priority
      Your Flutter and Firebase skills already provide a strong foundation
      for mobile development. Instead of adding another framework, your next
      step should be a production-quality project.
      Recommended action: Build and deploy a Flutter application with
      Firebase authentication, offline support, and push notifications.
      [View Career Plan]

      📄 Improve Your Resume ATS Score — Medium Priority
      Your resume demonstrates relevant mobile development skills, but some
      role-specific keywords and measurable project outcomes could be
      improved.
      [Improve Resume]
```

Card concepts: 🎯 Career Focus, 🚀 Portfolio Improvement, 🛠 Skill Development,
📄 Resume Improvement, 💼 Experience, 🎓 Certification, 📚 Learning/Preparation.

Each card shows: priority, concise title, short explanation, clear action,
appropriate navigation.

**The AI generates the FULL set of recommendations. The dashboard only
selects/renders the top 2–3 from the already-cached analysis — NO extra AI
call to pick dashboard cards.**

---

## 14. PHASE 12 — Do Not Break Existing Functionality

Before modifying code, inspect:

- existing recommendation models
- `engine.js`
- `student_dashboard_view.dart`
- AI service/provider
- Cloud Functions
- Resume Review usage/caching implementation
- existing navigation routes
- existing profile/portfolio/resume models

Reuse existing architecture. Do not duplicate AI provider logic. Do not create an
unrelated AI service if the existing one can be extended. Do not remove Resume
Review. Do not break auth, profile, portfolio, resume, or dashboard.

---

## 15. PHASE 13 — Implementation Order

1. **PHASE 1:** Fix routing bug.
2. **PHASE 2:** Remove fake 66% score + old rotating skill-gap presentation.
3. **PHASE 3:** Create Career Coach data model + structured AI response model.
4. **PHASE 4:** Integrate with existing AI provider architecture.
5. **PHASE 5:** Create normalized student career context.
6. **PHASE 6:** Implement AI prompt + structured JSON output.
7. **PHASE 7:** Validation, caching, stale-analysis detection, usage limits.
8. **PHASE 8:** Career Coach UI cards.
9. **PHASE 9:** Navigation for every recommendation type.
10. **PHASE 10:** Test with multiple different student profiles.

---

## 16. Test Cases

Test at least these scenarios:

| # | Profile | Expected |
|---|---|---|
| A | Flutter Mobile Developer (Flutter, Dart, Firebase) | Do NOT blindly recommend Kotlin/Swift |
| B | Web Developer (React, JavaScript, Node.js) | Web-relevant guidance |
| C | Cybersecurity (Nmap, Wireshark, Linux, networking) | Cybersecurity-oriented guidance |
| D | Data Science (Python, Pandas, NumPy, SQL) | Data-oriented guidance |
| E | Strong skills + weak portfolio | Portfolio/project recommendations dominate; no more tech tagging |
| F | Strong portfolio + weak resume/ATS | Resume improvement prioritized |
| G | Very little profile data | No hallucinated experience/skills; recommend completing missing profile info or limited guidance from available data only |

---

## 17. Final Requirement

The goal is NOT a smarter static skill-gap engine. The goal is to **replace the
skill-checklist mindset with a genuine AI-powered Career Coach** that analyzes the
student's available career evidence and determines the most useful next actions.

- Deterministic code → facts, validation, caching, cost control, navigation.
- AI model → career reasoning and personalization.
- Preserve the existing architecture and the Resume Review usage-control
  philosophy.
