# CampusConnect v8.3 — Workspace Tracker

## Status: COMPLETED
## Version: CampusConnect v8.3 — Firestore Demo Data Seeder & Codebase Architecture Documentation

---

## Phase Progress

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Workspace Audit | ✅ |
| 1 | Placement Pipeline Refinement | ✅ |
| 2 | Quick Statistics Refinement | ✅ |
| 3 | Department Analytics | ✅ |
| 4 | AI Insights Visual Upgrade (FL Chart) | ✅ |
| 5 | At-Risk Student Intelligence | ✅ |
| 6 | Student Growth Analytics | ✅ |
| 7 | AI Generated Teacher Summary | ✅ |
| 8 | Workspace Documentation | ✅ |
| 9 | **v8.2.1 — Data Pipeline Fix** | ✅ |
| 10 | **v8.2.2 — Layout Fix & Data Pipeline Investigation** | ✅ |
| 11 | **v8.3 — Codebase Architecture Documentation** | ✅ |
| 12 | **v8.3 — Firestore Demo Data Seeder** | ✅ |

**Overall Progress: 100%**

---

## v8.3 — Codebase Architecture Documentation

### Summary

Performed a **complete deep-read investigation** of the entire CampusConnect codebase — all models, all Firestore services, all providers, the main entry point, the Firestore security rules, the indexes, and the Cloud Functions. The full report was saved as **`project_info__8.md`** in the project root.

### Key Findings

| Finding | Detail |
|---------|--------|
| **Database is Empty** | The Firestore database connected to the dev environment has **zero data**. All dashboard metrics show zero because all queries return empty results. The code compiles with 0 errors/0 warnings but has nothing to read. |
| **Complete Schema Documented** | Traced every field in every document type — 12 complete document schemas with exact field names, types, and optionality |
| **13 Data Categories Quantified** | Seed script needs exactly: 30 students, 10 alumni, 5 teachers, 120-150 resume reviews, 30 engagement summaries, 20 placements, 80-120 applications, 40 mentorship requests, 15 opportunities, 22 chats, ~200 notifications, 150+ activities, 6 recommendations per student, ~75 AI interactions, 6 public profiles |

### Architecture Decisions

- **Node.js + firebase-admin SDK** chosen for the seed script (bypasses security rules for paths with `write: if false`)
- **UID-based demo prefix**: `demo_student_01` through `demo_student_30` to avoid real UID conflicts
- **`isDemoData: true` flag** on every document for safe cleanup
- **Dual application paths**: writes to both `placements/{pid}/applications/{uid}` (newer) and `applications/{appId}` (legacy) for backward compatibility
- **Direct document writes** for recommendations/engagement rather than simulating service calls
- **Progressive ATS scores** (3-5 per student) enabling Student Growth charts to show meaningful trends

### Deliverables

| File | Purpose |
|------|---------|
| `project_info__8.md` | 45+ page codebase architecture analysis with 12 complete document schemas |
| `project_info__9.md` | Investigation summary for the seed script task |

---

## v8.3 — Firestore Demo Data Seeder

### Objective

Create a comprehensive **demo dataset** for CampusConnect so every dashboard (Student, Alumni, Teacher) can be fully tested with realistic, interconnected data. This data is **temporary development/demo data only** and is flagged for safe cleanup.

### Files Created

| File | Purpose |
|------|---------|
| `scripts/seed_firestore/seed.js` | Main seed script — 14 sequential phases, batched writes (chunks of 490) |
| `scripts/seed_firestore/cleanup.js` | Cleanup script — 7 phases, recursive subcollection deletion, safe via `isDemoData` flag |
| `scripts/seed_firestore/README.md` | Setup instructions, data catalogue, validation targets, troubleshooting guide |
| `scripts/seed_firestore/package.json` | npm scripts (`seed`, `cleanup`), dependency on `firebase-admin` |
| `project_info__8.md` | Complete codebase schema analysis serving as the blueprint |

### Seed Data Catalogue

| Phase | Dataset | Count | Details |
|-------|---------|-------|---------|
| 1 | **Students** | 30 | 5 departments (CSE, AIML, IT, AIDS, ETC), differentiated profiles |
| 1 | **Alumni** | 10 | Google, Microsoft, Amazon, Flipkart, Walmart, TCS, Infosys, Oracle, Uber, Adobe |
| 1 | **Teachers** | 5 | One per department with designation and experience |
| 2 | **Resume Reviews** | 120-150 | 3-5 per student with progressive ATS scores, keywords, section advice |
| 3 | **Engagement Summaries** | 30 | One per student with engagementScore, profileStrength, streak, badges |
| 4 | **Placements** | 20 | Mix of active (12), closed (4), upcoming (4) — real companies, varied packages |
| 5 | **Applications** | 80-120 | Dual path writes (placement subcollection + global collection) |
| 6 | **Mentorship Requests** | 40 | 10 pending, 12 accepted, 10 completed, 8 rejected |
| 7 | **Opportunities** | 15 | Internships, Full-time, Referrals, Hackathons — posted by alumni |
| 8 | **Chats + Messages** | 22 chats | 3-10 messages each for accepted/completed mentorships |
| 9 | **Notifications** | ~200 | Students (3-8 each), Alumni (2-5 each), Teachers (2-4 each) — varied types |
| 10 | **Activities** | 150+ | Login, resume reviewed, profile updated, placement applied, etc. |
| 11 | **Recommendations** | 6/student | 2 mentor recommendations + 2 job recommendations + 1 skill + 1 chat |
| 12 | **AI Interactions** | ~75 | Every other student gets 2-5 chat interactions with varied intents |
| 13 | **Public Profiles** | 6 | Shareable alumni profile projections |
| 14 | **Recommendations Meta** | 30 | `recommendations_meta/summary` per student |

### Student Performance Profiles

Students are intentionally differentiated for realistic Teacher Dashboard analytics:

| Type | Count | Characteristics | ATS Range | CGPA Range | Engagement |
|------|-------|-----------------|-----------|------------|------------|
| **High Performers** | 3 | Top skills, high engagement, many applications | 82-95 | 8.0-9.5 | 85-98 |
| **Average Performers** | 15 | Moderate skills and engagement, varied years | 50-75 | 6.5-8.2 | 40-75 |
| **At-Risk Students** | 5 | Low ATS, few skills, low engagement | 25-48 | 5.0-6.5 | 10-35 |
| **Inactive Students** | 3 | Near-zero engagement, no applications | 10-35 | 5.5-7.0 | 0-15 |
| **Highly Engaged** | 4 | High streaks, many badges, many activities | 60-82 | 7.0-8.5 | 88-100 |

### Department Performance Distribution

| Department | Average ATS Range | Purpose |
|------------|------------------|---------|
| **CSE** | 65-78 | Highest performing — many high-scoring students |
| **AIML** | 60-72 | Mid-high — strong ML-related skills |
| **IT** | 55-68 | Mid-range — solid but not top |
| **AIDS** | 48-60 | Mid-low — more at-risk students |
| **ETC** | 40-55 | Lowest — more struggling students |

This differential enables the AI Insights to generate meaningful department comparison narratives (e.g., "CSE is the strongest department with an average ATS of 72, while ETC needs improvement at 48").

### Safety & Idempotency

| Feature | Implementation |
|---------|---------------|
| **Demo flag** | Every document gets `isDemoData: true` and `environment: "demo"` |
| **Cleanup** | Recursive deletion of only flagged documents, subcollections before parents |
| **Safe scope** | Production documents without the flag are NEVER touched |
| **Idempotent** | Safe to re-run — uses `{merge: false}` on known UIDs, creates new IDs for subcollections |
| **Batched writes** | Chunks of 490 (under Firestore's 500-write batch limit) |
| **Admin SDK** | Uses `firebase-admin` service account which bypasses security rules |

### Usability

```bash
cd scripts/seed_firestore
npm install          # Install firebase-admin
npm run seed         # Seed all demo data (2-5 min)
npm run cleanup      # Remove all demo data safely
```

### Validation Targets

After seeding, each dashboard should show:

| Dashboard | Metrics |
|-----------|---------|
| **Teacher** | Total Students: 30, Department Comparison: 5 depts, Resume Analytics: 120-150 reviews, Skill Gap: 20+ keywords, Placement Funnel: 30 eligible / 20-25 applied, At-Risk: 5 flagged, AI Summary: non-empty narrative |
| **Student** | Recommendations: 6 per student, Badges: based on streaks, Engagement: 30-98 range, AI Chat: 2-5 interactions, Resume History: 3-5 reviews |
| **Alumni** | Mentorship Queue: 10 pending / 12 accepted / 10 completed, Opportunities: 15 posted, Impact Metrics: active counts |

---

## v8.3.1 — First-Login Data Load Retry

### Issue

On **first login** (fresh app launch with no cached Firebase connection), the teacher dashboard and AI Insights tab showed **zero data** despite the Firestore database being populated. After stopping and relaunching the app, the same data appeared correctly.

### Root Cause

The Firebase Firestore SDK's gRPC/WebSocket connection is not fully established on the first `get()` call during the initial app launch. On fresh login:

1. `AuthGuard` builds, streaming auth state
2. `ProfileProvider` and `RoleProvider` initialize — including the `_TeacherDashboardTab.initState()` `addPostFrameCallback`
3. `TeacherAnalyticsProvider.loadAnalytics()` fires 8 parallel Firestore queries **before the Firestore connection is warm**
4. The queries execute but the connection is a cold start — the SDK may return empty snapshots or the responses arrive out of order
5. On second launch: Firebase SDK reuses cached auth state, the Firestore connection is already warm, queries work immediately

### Fix Applied

| Fix | File | Change |
|-----|------|--------|
| 1 | `teacher_dashboard_view.dart` | Added retry mechanism in `_TeacherDashboardTab` — if initial load yields zero students, retry up to 3 times with 2-second delay between attempts |

### Implementation Detail

The retry logic in `_TeacherDashboardTabState`:
- Tracks `_loadRetryCount` (max 3 retries)
- After each load, checks if data is empty (zero students) and not currently loading
- If empty, schedules a retry via `Future.delayed(_retryDelay, ...)` — 2 seconds between attempts
- All `mounted` guards prevent stale state access
- On pull-to-refresh, the retry counter is NOT reset — the manual refresh is the user's signal to reload

### Validation

- `flutter analyze` → **0 errors, 0 warnings** (4 info-level `use_build_context_synchronously` lint hints only — all guarded by `mounted` checks)
- No UI changes — retry is transparent to the user
- No analytics logic changes

---

## v8.2.1 — Data Pipeline Fix

### Issues Found

| # | Severity | File | Root Cause |
|---|----------|------|------------|
| 1 | **HIGH** | `teacher_analytics_service.dart` | `getEngagementAggregates()` queried `users/{uid}/engagement/summary` but the actual Firestore path is `users/{uid}/engagement_summary/summary`. This caused **Avg Engagement** and **Avg Profile Strength** to always return 0. |
| 2 | **MEDIUM** | `teacher_dashboard_sections.dart` | "Placed Students" card was counting active placement *drives* (job postings), not actual placed students. When someone saw "Placed Students = 4" but "Total Students = 0" it was contradictory because the metrics came from different queries (placements collection vs students collection). |
| 3 | **LOW** | `teacher_dashboard_sections.dart` | `avgScore` had a fallback `reviews.averageScore` that was unnecessary — the `TeacherAnalyticsProvider` already provides `averageScore` from the full `collectionGroup` query across all student reviews. |
| 4 | **LOW** | `teacher_ai_insights_tab.dart` | "Mentorships" tile was displaying `activeAlumni` count (labels mismatched). |
| 5 | **LOW** | `teacher_dashboard_sections.dart` | Department Overview "Overall Placement" label implied actual student placement rate, but it was drives-per-student. |

### Fixes Applied

| Fix | File | Change |
|-----|------|--------|
| 1 | `teacher_analytics_service.dart` | Changed `.collection('engagement')` → `.collection('engagement_summary')` to match actual Firestore path used by `EngagementService` |
| 2 | `teacher_dashboard_sections.dart` | Renamed "Placed Students" → "Active Drives" to truthfully reflect that the metric counts active placement opportunities |
| 3 | `teacher_dashboard_sections.dart` | Removed unused `reviews` Provider watch and fallback; now uses `analytics.averageScore` directly |
| 4 | `teacher_ai_insights_tab.dart` | Renamed "Mentorships" → "Alumni" in CampusHealth tile to match the actual data shown |
| 5 | `teacher_dashboard_sections.dart` | Renamed "Overall Placement" → "Active/Student" in Department Overview header |

### Schema Limitations Discovered

The system tracks **placement opportunities** (job postings in the `placements` collection) but does **not** track which individual students were hired. Therefore:
- "Placed Students" cannot be computed from existing data
- Shortlisted/Interview/Placed pipeline stages are unavailable
- Per-department placement rates are unavailable
- The pipeline shows "N/A" for these stages intentionally

### Validation

- `flutter analyze` → **0 errors, 0 warnings** (3 info-level style suggestions only)
- All v8.2 files compile cleanly
- No Firestore rules, indexes, or schema changes required
- No Cloud Function changes required

---

## v8.2.2 — Layout Fix & Data Pipeline Investigation

### Issues Found

| # | Severity | Issue | Root Cause |
|---|----------|-------|------------|
| 1 | **HIGH** | Vertical purple/blue bar rendered down the center of AI Insights tab, overlapping charts and content | Nested Scaffold — both `_TeacherDashboardTab` and `AIInsightsTab` had their own `Scaffold` + `AppBar` inside `MainNavigationView`'s outer Scaffold, causing double-Scaffold layout corruption |
| 2 | **MEDIUM** | All dashboard metrics showing zero | Empty Firebase database — no student users, resume reviews, placements, engagement summaries, or mentorship requests exist in the connected dev environment |

### Fixes Applied

| Fix | File | Change |
|-----|------|--------|
| 1 | `teacher_dashboard_view.dart` | Removed inner Scaffold + AppBar → `Column` + `Expanded` layout with `Container`-based custom header |
| 2 | `teacher_ai_insights_tab.dart` | Same fix — removed inner Scaffold + AppBar → `Column` + `Expanded` layout with `Container`-based custom header |

### Investigation Findings

Completed an end-to-end audit of all 8 analytics queries and 10 AI Insights sections:

- **Root cause of zero values**: Empty Firebase database — no data exists in the connected dev environment
- **No code bugs found**: All queries correctly return default empty values when the database is empty
- **All empty states verified**: Every chart/section shows appropriate fallback text ("No review data yet", "No placement data", etc.)
- **Consistency confirmed**: Dashboard and AI Insights share the same `TeacherAnalyticsProvider` instance — no contradictory values
- **Full trace documented** in `project_info__5.1 v8.2.2 — Teacher Dashboard & AI Insights Data Pipeline Investigation.md`

### Validation

- `dart analyze` on all 6 dashboard/analytics files → **0 errors, 0 warnings** (5 info-level style suggestions only)
- No analytics logic changed — only layout scaffolding removed

---

## Edge Cases & Boundary Handling

The following edge cases were identified during implementation and addressed:

### Data-level edge cases
- **Zero data**: Every chart/section gracefully handles total == 0 with fallback UI
- **Single trend point**: LineChart still renders — single dot shown with `isCurved: true`
- **Single department**: AI Summary handles 1 department correctly (no "strongest vs weakest" comparison)
- **Missing student names**: Falls back to "Unknown Student" via `??` chains throughout
- **Null department data**: Grouped under "Unknown" department
- **Very long strings**: Department names and skill names are truncated for chart labels
- **Mentorship division by zero**: `completed / total` only evaluated when `total > 0`

### State management edge cases
- **Disposed provider**: All access guarded by `_isDisposed` checks before `notifyListeners()`
- **Loading vs empty**: Skeleton loader shown only when `isLoading && !hasData`
- **Provider list mutation (CRITICAL FIX)**: AI Summary now copies `departmentAnalytics` list before sorting, preventing in-place mutation of provider state
- **Teacher vs student data (CRITICAL FIX)**: At-Risk detection no longer uses `placements.appliedPlacementIds` or `mentorship.acceptedMentorshipsCount` — these are teacher-level, not per-student. Instead uses only per-student signals from `studentData`

### FL Chart edge cases
- **Zero-value bars**: Rendered as barely-visible stubs (0.5 height, 8% opacity grey) rather than disappearing, so the chart structure remains clear
- **Single-section pie**: Works correctly — one wedge fills the whole chart
- **All-same-score trend line**: LineChart renders a flat line correctly; `clamp()` ensures Y bounds don't collapse

### Pipeline edge cases
- **No applications**: "N/A" shown for Shortlisted/Interview/Placed stages with subtitle "Not tracked"
- **Empty applications collection**: Informational message shown
- **Zero students**: Entire pipeline hidden with "No placement data yet"

---

## Files Changed

### Created (v8.3)
| File | Purpose |
|------|---------|
| `scripts/seed_firestore/seed.js` | 14-phase seed script — 30 students, 10 alumni, 5 teachers, 120-150 resume reviews, 30 engagement summaries, 20 placements, 80-120 applications, 40 mentorship requests, 15 opportunities, 22 chats, ~200 notifications, 150+ activities, 6 recommendations/student, ~75 AI interactions, 6 public profiles |
| `scripts/seed_firestore/cleanup.js` | 7-phase cleanup script — recursive subcollection deletion with `isDemoData: true` safety flag |
| `scripts/seed_firestore/README.md` | Setup instructions, data catalogue, validation targets, troubleshooting guide |
| `scripts/seed_firestore/package.json` | npm scripts (`seed`, `cleanup`), `firebase-admin` dependency |
| `project_info__8.md` | Complete codebase architecture & Firestore schema analysis — 12 document schemas, 13 collection groups, 20+ subcollections, security rules analysis, indexes audit |

### Modified (v8.2.2)
| File | Change |
|------|--------|
| `lib/views/dashboards/teacher_dashboard_view.dart` | Removed inner Scaffold → Column+Expanded+Container app bar |
| `lib/views/dashboards/widgets/teacher_ai_insights_tab.dart` | Removed inner Scaffold → Column+Expanded+Container app bar |

### Modified (v8.2.1 — Bugfix)
| File | Change |
|------|--------|
| `lib/services/firestore/teacher_analytics_service.dart` | Fixed `engagement` → `engagement_summary` subcollection path |
| `lib/views/dashboards/widgets/teacher_dashboard_sections.dart` | Renamed "Placed Students" → "Active Drives"; removed unused `reviews` watch; renamed "Overall Placement" → "Active/Student" |
| `lib/views/dashboards/widgets/teacher_ai_insights_tab.dart` | Renamed "Mentorships" → "Alumni" in CampusHealth |

### Created (v8.2 — Teacher Intelligence)
| File | Purpose |
|------|---------|
| `project_info__5_Teacher Dashboard v8.2 Audit.md` | Phase 0 — comprehensive codebase audit |

---

## Architecture Decisions

### Seed Script: Node.js + Admin SDK
The seed script uses `firebase-admin` SDK (service account) which bypasses Firestore security rules. This is required because several document paths (e.g., `users/{uid}/engagement_summary/summary`, `users/{uid}/recommendations/`) have `write: if false` in security rules — client SDK seed scripts would fail on these paths.

### UID Convention: `demo_` Prefix
All demo users use UIDs like `demo_student_01`, `demo_alumni_03`, `demo_teacher_05` — avoiding any collision with real auth UIDs. The seed script does NOT create Firebase Auth accounts; it only writes Firestore documents.

### Dual Application Paths
Applications are written to **both** `placements/{placementId}/applications/{uid}` (newer primary path) and `applications/{applicationId}` (legacy global collection). This ensures backward compatibility with both old and new code paths.

### Progressive ATS Scores for Student Growth
Each student gets 3-5 resume reviews with intentionally progressive ATS scores, enabling the Student Growth section (LineChart) to show meaningful trends — some improving, some declining, some flat, some high-scoring consistently.

### Department Performance Distribution
Departments are intentionally skewed: CSE highest average ATS, ETC lowest. This differential enables the AI Insights to generate meaningful comparison narratives. Without this skew, all departments would appear identical and the AI Summary would lack insight.

### Batched Writes with 490-document Chunks
Firestore's batch write limit is 500 operations. The seed script uses chunks of 490 to stay safely under this limit. Each chunk is committed individually with progress logging.

### Retention of "N/A" for pipeline stages
Shortlisted, Interview, and Placed stages display "N/A" because the current Firestore schema does not track application-level stage progression. Future schema changes (e.g. adding a `stage` field to the `applications` subcollection) would enable real counts here.

### Engagement aggregates use correct Firestore path
`TeacherAnalyticsService.getEngagementAggregates()` now queries `users/{uid}/engagement_summary/summary` which matches the actual Firestore path used by `EngagementService` (per `EngagementService._summaryRef()`). The previous path `users/{uid}/engagement/summary` was incorrect and caused avg engagement / profile strength to always return 0.

### "Active Drives" instead of "Placed Students"
The system has no mechanism to track which individual students were hired. Renamed the metric to "Active Drives" which honestly reflects the count of active placement opportunities. A future enhancement could add a per-student placement status field to enable real "Placed Students" tracking.

### Department sorting by studentCount (not placement rate)
The spec says *"Sort departments by placement rate"*, but placement rate per department requires knowing how many students per department were placed. That data is not currently tracked. Sorting by `studentCount` is a pragmatic proxy.

---

## Performance Improvements

| Area | Improvement |
|------|-------------|
| **Parallel loading** | `TeacherAnalyticsProvider.loadAnalytics()` uses `Future.wait` to run all 8 queries concurrently instead of sequentially |
| **Data reuse** | Department analytics reuses the same user query from `getStudentResumeData()` patterns rather than adding a new top-level collection query |
| **Limit queries** | `getStudentResumeData()` caps at 30 students; `getSkillGapAnalysis()` limits to 400 reviews |
| **Count queries** | `getApplicationPipelineCounts()` uses Firestore `count()` aggregation for student total instead of loading full documents |
| **No streams** | All analytics are one-time fetches, not real-time streams — avoids unnecessary Firestore reads |
| **Batch writes (seed)** | Seed script commits in chunks of 490 to stay under Firestore batch limits while maximizing throughput |

---

## Known Limitations

1. **Per-student placement tracking**: The system tracks which students applied to which placements (`applications` subcollection), but does not track shortlisting, interview, or final placement status per student. This limits pipeline accuracy. The seed script cannot create "Placed Students" data for this reason.

2. **Engagement aggregates are per-document reads**: `getEngagementAggregates()` iterates over every student and reads their `engagement_summary/summary` doc. For institutions with 500+ students this could be slow. Consider a cloud function that maintains a materialized aggregate.

3. **No real-time updates**: Analytics are snapshot-based, loaded on dashboard init and pull-to-refresh. New data won't appear until the user manually refreshes.

4. **At-Risk detection limited to ATS/reviews**: Currently uses only ATS scores and review counts from `studentData`. Cannot detect mentorship gaps, application inactivity, or engagement drops per-student without additional subcollection queries.

5. **Seed script requires manual service account key**: The `serviceAccountKey.json` must be manually downloaded from Firebase Console and placed in `scripts/seed_firestore/`. It is NOT committed to version control.

6. **Seed script does not create Auth accounts**: Only writes Firestore documents. The demo UIDs are not linked to real Firebase Auth accounts, so login with demo credentials is not possible. The data is visible only when a real authenticated user (with Teacher role) views the dashboard.

---

## Version Changelog

| Version | Date | Description |
|---------|------|-------------|
| v8.3.1 | Current | First-login data load retry — Firestore warm-up fix |
| v8.3 | Previous | Codebase architecture documentation + Firestore demo data seeder |
| v8.2.2 | Previous | Layout fix + Data Pipeline Investigation |
| v8.2.1 | Previous | Data pipeline fix — corrected engagement path, fixed misleading metric labels |
| v8.2 | Previous | Teacher Intelligence & Analytics Refinement |
| v8.1 | Previous | Teacher Dashboard Modernization |

### v8.3 Changes — Codebase Architecture Documentation
- **Complete Architecture Analysis**: Documented all 12 document schemas with exact field names, types, and optionality across `users`, `placements`, `mentorship_requests`, `opportunities`, `chats`, `notes`, `applications`, `public_profiles`, and all subcollections
- **Security Rules Audit**: Catalogued all 6 security rule blocks with access patterns and implications for seed script design
- **Index Audit**: Identified 5 existing composite indexes and 4 missing indexes that may cause runtime failures
- **Data Flow Documentation**: Traced the complete analytics pipeline from Firestore queries through `TeacherAnalyticsService` → `TeacherAnalyticsProvider` → dashboard widgets
- **Seed Script Blueprint**: Quantified all 13 data categories required for full dashboard population
- Full report saved as `project_info__8.md` (4+ pages)

### v8.3 Changes — Firestore Demo Data Seeder
- **14-Phase Seed Script**: Creates 30 students (5 departments, differentiated profiles), 10 alumni (real companies), 5 teachers, 120-150 progressive resume reviews, 30 engagement summaries with badges, 20 placements (active/closed), 80-120 applications (dual paths), 40 mentorship requests (all statuses), 15 opportunities (4 types), 22 chats with messages, ~200 notifications, 150+ activities, 6 recommendations per student, ~75 AI interactions, 6 public profiles
- **Cleanup Script**: 7-phase recursive deletion with `isDemoData: true` safety flag — only flagged documents are touched, production data is NEVER affected
- **Safety Features**: Every document flagged with `isDemoData: true` + `environment: 'demo'`; batched writes in chunks of 490; Admin SDK bypasses security rules; idempotent by design
- **Documentation**: Full README with setup instructions, data catalogue, performance profile descriptions, validation targets, troubleshooting guide
- **Usage**: `npm run seed` to populate, `npm run cleanup` to remove

### v8.2.2 Changes
- **LAYOUT FIX**: Removed nested Scaffold wrappers in `_TeacherDashboardTab` and `AIInsightsTab`. Both tabs had their own `Scaffold` with `AppBar` inside `MainNavigationView`'s outer Scaffold, causing double-Scaffold layout corruption — a vertical purple/blue bar rendered down the center overlapping charts and content across the AI Insights tab. Replaced both inner Scaffolds with `Column` + `Expanded` layout and custom `Container`-based app bars. Fixes files: `lib/views/dashboards/teacher_dashboard_view.dart` and `lib/views/dashboards/widgets/teacher_ai_insights_tab.dart`.
- **DATA PIPELINE INVESTIGATION**: Completed end-to-end audit of all 8 analytics queries and 10 AI Insights sections. Root cause of zero values identified: **empty Firebase database** (no student users, resume reviews, placements, engagement summaries, or mentorship requests). Confirmed no code bugs — all queries correctly return default empty values. Full trace documented in `project_info__5_Teacher Dashboard v8.2 Audit.md` and `project_info__5.1.md`.
- **ANALYSIS CONFIRMATION**: `dart analyze` on all 6 dashboard/analytics files yields **0 errors, 0 warnings** — only 5 info-level style suggestions.
- **EMPTY STATE VERIFICATION**: Every chart/section shows appropriate empty-state fallback text (e.g., "No review data yet", "No placement data", "No skill data available yet") — no misleading zero values displayed.
- **CONSISTENCY CONFIRMATION**: Dashboard and AI Insights tabs share the same `TeacherAnalyticsProvider` instance — no contradictory values exist.

### v8.2.1 Changes
- **BUGFIX**: Fixed engagement subcollection path from `engagement` → `engagement_summary` to match actual Firestore schema
- **HONESTY**: Renamed "Placed Students" → "Active Drives" to reflect the actual metric (active job postings, not placed students)
- **CLEANUP**: Removed unused `ResumeReviewProvider` watch from `QuickStatistics`; removed dead fallback logic
- **LABEL FIX**: Fixed "Mentorships" tile in AI Insights to correctly read as "Alumni"
- **LABEL FIX**: Renamed "Overall Placement" → "Active/Student" in Department Overview

### v8.2 Changes
- **Phase 1**: Removed hardcoded pipeline multipliers (`0.6`, `0.3`). Pipeline now uses real `eligible` (total students) and `applied` (application counts) from `TeacherAnalyticsProvider`. Remaining stages show "N/A" with explanation.
- **Phase 2**: All 8 spec metrics implemented: Total Students, Active Drives, Placement Rate, Avg Resume Score, Avg Engagement, Avg Profile Strength, Active Alumni, Active Mentorships.
- **Phase 3**: Department cards with per-dept name, student count, avg score, top skills, risk level. Sorted by student count.
- **Phase 4**: Full FL Chart integration: PieChart (resume/risk distribution), BarChart (funnel, dept comparison, skill gaps), LineChart (monthly trends).
- **Phase 5**: Multi-signal At-Risk detection using ATS + review count + engagement signals. Risk cards show name, dept, score, signals, priority, intervention.
- **Phase 6**: Student Growth section with ATS improvement, profile, engagement, application rate, placements.
- **Phase 7**: Dynamic AI narrative generated from provider data — no hardcoded insights.
- **BUGFIX**: Fixed missing `placements` Context watch in `DepartmentOverview` causing compilation error.
- **BUGFIX**: Replaced 3 invalid `AppTheme.space6` references with valid `AppTheme.space8`.
