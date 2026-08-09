# CampusConnect — v8.7 Implementation Task

## Alumni Experience Simplification & Alumni Group Chat

You are working on the existing **CampusConnect Flutter + Firebase application**.

Before making any changes, inspect the current codebase, architecture, routes, providers, services, Firestore schema, security rules, and the existing v8.6 implementation.

---

# v8.7 — Alumni Experience Simplification & Alumni Group Chat

## Objective

Simplify the Alumni experience based on the actual intended role of Alumni.

Alumni should **not be required to build or maintain a Student-style Portfolio**.

The existing full Resume Portfolio system remains a **Student feature only**.

For Alumni:

1. Remove/disable the Alumni-facing Portfolio workflow.
2. Restore the previous **text-based Resume Reviewer** experience.
3. Alumni can optionally paste their resume text and receive ATS/AI analysis.
4. Do NOT require Alumni to upload a PDF resume.
5. Do NOT require Alumni to enter education, projects, certifications, skills, experience, social links, career preferences, etc. into CampusConnect.
6. Add an **Alumni Group Chat** where Alumni can communicate with other Alumni.
7. Keep the implementation minimal, practical, and consistent with the existing architecture.
8. Do not redesign the entire application.

The goal is to make the Alumni experience useful without requiring unnecessary data entry or time-consuming portfolio maintenance.

---

# 1. Role Separation

The application must clearly separate Student and Alumni experiences.

### Student

Students continue using:

My Portfolio
→ Resume Upload
→ Uploaded PDF Resume
→ Review Uploaded Resume
→ ATS Score
→ Review History
→ Portfolio data
→ Resume Summary Card
→ Placement Resume Snapshot

Do NOT remove or break any Student functionality.

### Alumni

Alumni should NOT use the Student Portfolio workflow.

Remove/hide Alumni access to:

* My Portfolio
* Edit Portfolio
* Upload Resume to Portfolio
* Replace Portfolio Resume
* Portfolio Strength
* Portfolio Projects
* Portfolio Certifications
* Portfolio Experience management
* Portfolio Skills management
* Portfolio Social Links
* Portfolio Career Preferences
* Portfolio Resume Metadata
* Student-style ResumeSummaryCard

Do not delete the underlying Student Portfolio implementation.

This is a **role-based UI/access change**, not removal of the Student Portfolio subsystem.

---

# 2. Alumni Resume Reviewer

Restore the original/simple Resume Reviewer flow for Alumni.

Alumni should see:

Resume Review

AI Resume Review
ATS Optimization & Feedback

Target Role (Optional)

Resume Text

[Paste resume content here...]

Analyze Resume

The Alumni reviewer should work using pasted resume text.

### Important

Alumni should NOT be required to:

* upload a PDF
* create a portfolio
* maintain resume metadata
* maintain projects
* maintain certifications
* maintain education
* maintain social links

The text reviewer should remain optional.

If an Alumni wants ATS analysis, they paste their resume text and run the existing AI Resume Reviewer.

---

# 3. Reuse Existing Resume Review Pipeline

Do NOT create a second AI/ATS engine.

Reuse the existing Resume Review infrastructure wherever possible.

The existing pipeline should continue to handle:

* target role
* resume text
* AI analysis
* ATS score
* feedback
* quota
* review history

However, Alumni should use the **text-input path** rather than the Student uploaded-PDF path.

Do not break the existing Student uploaded-PDF reviewer.

The final architecture should effectively be:

Student:
Uploaded PDF → server extraction → existing Resume Review pipeline

Alumni:
Pasted Resume Text → existing Resume Review pipeline

Both should produce the same review/ATS response format.

---

# 4. Alumni Review History

Alumni may continue seeing their own Resume Review history if the existing history system already supports it.

Keep history isolated by UID.

An Alumni must only see:

users/{uid}/resumeReviews

They must never see another user's review history.

Do not introduce a new history collection if the existing system can be reused.

---

# 5. Remove Alumni Portfolio Navigation

Audit all Alumni navigation surfaces.

Remove/hide Portfolio-related navigation from:

* Alumni Profile
* Alumni Dashboard
* Alumni navigation
* Alumni quick actions
* Alumni resume cards
* Any Alumni-only portfolio routes

Do NOT remove routes or screens that Students still use.

Use role-aware routing/visibility.

If a Portfolio route is manually accessed by an Alumni, handle it safely rather than allowing the Alumni to enter the Student Portfolio editing workflow.

---

# 6. Alumni Group Chat

Add a new Alumni-only group communication feature.

The purpose is simple:

> Allow verified Alumni users to communicate with other Alumni in one shared group.

The initial version should be a **single shared Alumni Group Chat**, not a complex Discord-style system.

Example:

## Alumni Community

Alumni 1: Anyone working in...
Alumni 2: Yes, I can help...
Alumni 3: Has anyone...
-----------------------

[Type a message...]

The group should contain only Alumni users.

Students and Teachers must not be able to participate in this Alumni group.

---

# 7. Group Chat Data Model

Use Firestore.

Prefer a simple structure such as:

alumni_group_messages/{messageId}

Suggested fields:

* senderId
* senderName
* senderPhotoUrl (optional)
* message
* createdAt
* editedAt (optional)
* isDeleted (optional)

Use the authenticated user's UID as the authoritative sender identity.

Do not trust a client-provided senderId.

---

# 8. Group Chat Security

Firestore rules must enforce:

### Read

Only authenticated Alumni can read Alumni group messages.

### Create

Only authenticated Alumni can create messages.

The sender UID must equal:

request.auth.uid

### Update/Delete

A user may only modify/delete their own message, unless an existing Admin moderation mechanism is deliberately reused.

Students must be denied.

Teachers must be denied unless the existing product requirements explicitly require teacher participation.

Unauthenticated users must be denied.

Do not weaken existing Firestore security rules.

---

# 9. Alumni Chat UI

Create a simple Material 3 chat screen consistent with the existing CampusConnect design.

Suggested:

Alumni Community

[message list]

Each message should show:

* sender name
* message
* timestamp

The current user's messages can be visually distinguished from other Alumni messages.

Bottom:

[ Type a message... ] [Send]

Support:

* empty state
* loading state
* error state
* sending state
* automatic scrolling to recent messages
* real-time Firestore updates

Do not over-engineer the first version.

---

# 10. Alumni Dashboard

Modify the Alumni Dashboard to focus on useful Alumni functionality.

Remove the Portfolio/Resume Portfolio dependency.

Recommended primary actions:

* Alumni Community
* Resume Review
* Profile
* Existing Alumni features

The dashboard should not imply that Alumni must build a portfolio.

Do not remove existing working Alumni functionality unrelated to Portfolio.

---

# 11. Alumni Profile

The Alumni Profile should remain lightweight.

Do not introduce Portfolio editing requirements.

Keep existing basic profile information already required by the application.

Do not force Alumni to provide:

* projects
* certifications
* education history
* skills
* experience entries
* career preferences
* social links

unless those fields are already required for another existing feature.

---

# 12. Existing Student Portfolio Protection

This version must NOT regress the Student Portfolio system.

Verify that Students can still:

* open My Portfolio
* edit portfolio
* upload resume
* replace resume
* delete resume where allowed
* review uploaded resume
* view ATS score
* view review history
* see ResumeSummaryCard
* use placement resume snapshots

Student functionality must remain unchanged.

---

# 13. Existing Read-Only Student Portfolio

Alumni viewing a Student's profile/portfolio must remain strictly read-only if that functionality already exists.

However, distinguish:

Alumni's own profile
→ NO Portfolio workflow

Alumni viewing Student
→ Existing read-only Student Portfolio

Do not accidentally remove the read-only student portfolio capability.

Alumni must never gain:

* upload
* replace
* delete
* review
* ATS-write
  permissions over a Student's resume.

---

# 14. Routes

Audit the current route table.

Add a route for the Alumni Group Chat, for example:

alumniGroupChatRoute

Use the project's existing routing conventions rather than inventing a new routing architecture.

Remove/hide Alumni access to Student Portfolio routes where appropriate.

Do not remove routes required by Students.

---

# 15. Services / Providers

Follow the existing architecture.

If the project currently uses:

Services
→ Providers
→ Views

continue using that pattern.

Create only what is necessary, for example:

AlumniGroupChatService
AlumniGroupChatProvider
AlumniGroupChatView

Do not introduce unnecessary state-management or architecture changes.

---

# 16. Firestore Indexes

Inspect whether the Alumni group chat query requires an index.

If messages are queried by:

createdAt ASC/DESC

add the required Firestore index only if Firebase requires it.

Do not blindly add unnecessary indexes.

---

# 17. Notifications

Do NOT implement a complicated notification system in this version unless the existing architecture makes it trivial and safe.

The first version only needs real-time chat functionality.

Avoid scope creep.

---

# 18. Existing Resume Review Quota

The existing Resume Review quota must continue working.

Alumni text reviews must:

* consume quota correctly
* reject when quota is exhausted
* not bypass security
* not create duplicate usage records

Reuse the existing quota implementation.

Do not create a separate Alumni quota.

---

# 19. Existing AI Analytics / History

Preserve existing analytics/history behavior where compatible.

If the existing Resume Review pipeline already records:

* review history
* usage
* analytics events

reuse it.

If an event currently assumes every review has an uploaded PDF/storagePath, make that field optional rather than breaking Alumni text reviews.

Example:

source:

* "uploaded" for Student uploaded-PDF reviews
* "manual" or existing equivalent for text reviews

Use the project's existing naming conventions where possible.

---

# 20. Files To Audit Before Editing

Inspect at minimum:

* Alumni Dashboard
* Alumni Profile
* Resume Review View
* Resume Review Provider
* Resume Review Service
* Portfolio Provider
* Portfolio Service
* Resume Service
* Student Portfolio screens
* routing configuration
* Firestore rules
* Firestore indexes
* Cloud Functions related to Resume Review
* existing chat implementation
* existing notification implementation
* user role/profile models

Do not assume the exact file structure.

Use the actual repository architecture.

---

# 21. Testing Requirements

Add tests for the new Alumni behavior.

At minimum test:

### Alumni Portfolio

1. Alumni cannot access Student Portfolio editing workflow.
2. Student Portfolio remains accessible to Students.
3. Alumni cannot modify Student Portfolio data.

### Alumni Resume Reviewer

4. Alumni can submit resume text.
5. Alumni text review reaches the existing Resume Review pipeline.
6. Alumni review history is stored under their own UID.
7. Alumni cannot access another user's review history.
8. Resume quota is enforced.
9. Empty/too-short resume text is rejected using existing validation.
10. Student uploaded-PDF review remains functional.

### Alumni Group Chat

11. Alumni can read group messages.
12. Alumni can send messages.
13. Sender identity comes from Firebase Auth.
14. Students cannot read the Alumni group.
15. Students cannot write to the Alumni group.
16. Teachers cannot write to the Alumni group unless explicitly allowed.
17. Unauthenticated users cannot access the group.
18. Alumni can only modify/delete their own messages if modification is implemented.
19. Messages appear in real time.
20. Empty chat state works correctly.

---

# 22. Manual Testing Matrix

After implementation, manually verify:

### Student

* Login as Student
* My Portfolio works
* Upload Resume works
* Review Uploaded Resume works
* ATS appears
* Review history works
* Student dashboard ResumeSummaryCard works

### Alumni

* Login as Alumni
* Alumni Dashboard does NOT show Student Portfolio
* Alumni Profile does NOT show My Portfolio
* Resume Reviewer opens normally
* No PDF upload is required
* Paste resume text
* Analyze Resume
* ATS result appears
* Review history works
* Open Alumni Community
* Existing Alumni messages load
* Send a message
* Message appears in real time
* Logout/login and verify chat remains
* Alumni cannot access Student Portfolio editing

### Security

* Login as Student → try Alumni Group Chat → denied/not accessible
* Login as Teacher → try Alumni Group Chat → denied/not accessible
* Logout → try Alumni Group Chat → denied
* Alumni → attempt to modify Student Portfolio → denied
* Alumni → attempt to review another user's uploaded resume → denied

---

# 23. Validation

Run:

flutter analyze

flutter test

node --check functions/index.js

dart format on changed Dart files

Fix all errors/warnings introduced by this version.

Do not modify unrelated pre-existing info-level lints.

---

# 24. Documentation

Update:

* docs/todo.md
* docs/issues.md
* docs/v8_workspace_tracker.md
* docs/confirmation.md

Document:

* why Alumni Portfolio was removed
* Alumni now use text-based Resume Review
* Alumni Group Chat architecture
* security rules
* role separation
* tests performed
* deployment status

Do not describe this as deleting the Student Portfolio system.

The correct architectural statement is:

> Portfolio is a Student career-development feature. Alumni use a lightweight profile + optional text-based Resume Review + Alumni Community Chat.

---

# 25. Version

Update the application version from the current v8.6 version to the appropriate v8.7 version.

Follow the existing version/build-number convention in pubspec.yaml.

Do not arbitrarily choose a build number if the repository already establishes the next number.

---

# 26. Important Constraints

DO NOT:

* redesign the entire application
* remove Student Portfolio
* remove Student Resume Reviewer
* create a second AI/ATS engine
* create a second resume storage system for Alumni
* force Alumni to upload resumes
* force Alumni to build portfolios
* force Alumni to enter unnecessary personal/career data
* weaken Firestore security
* allow Students into the Alumni group
* allow cross-user resume review
* introduce unnecessary dependencies
* change unrelated working features
* create unnecessary indexes
* create a complicated social network

Keep the implementation focused.

---

# Final Expected Architecture

### Student

Student Dashboard
→ My Portfolio
→ Full Portfolio
→ Uploaded Resume PDF
→ Resume Review
→ ATS
→ Review History
→ Placement Resume Snapshot

### Alumni

Alumni Dashboard
→ Lightweight Profile
→ Text Resume Reviewer
→ ATS / Feedback
→ Review History
→ Alumni Community Chat

### Alumni → Student

Student Portfolio
→ Read-only access only
→ No editing
→ No resume upload
→ No resume replacement
→ No resume deletion
→ No resume review
→ No ATS writes

The final result should make Alumni participation **low-friction** while preserving the complete Student career/portfolio system.
