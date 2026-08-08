# CampusConnect v8.5 — Resume Reviewer Integration & PDF Intelligence

You are working on the CampusConnect Flutter + Firebase project.

## IMPORTANT — READ BEFORE CHANGING CODE

This project has completed:

* v8.4 — Student Resume Portfolio
* v8.4.1 — Resume Portfolio + Firebase Storage Foundation
* v8.4.2 — Issues Hardening
* v8.4.3 — Manual-Test Bug Fixes
* v8.4.4 — On-device re-verification
* v8.4.8 — Portfolio read/refresh fixes
* v8.4.9 — Flattened portfolio shape read fix + email backfill

The current architecture is already deployed and working.

**DO NOT redesign the portfolio architecture.**
**DO NOT replace the nested `users/{uid}/portfolio` design.**
**DO NOT introduce a second resume storage architecture.**
**DO NOT break existing ATS review, placement snapshots, teacher/alumni portfolio access, or Firebase Storage rules.**

---

# Version Goal

## v8.5 — Resume Reviewer Integration & PDF Intelligence

The goal of v8.5 is to make the student's uploaded resume in Firebase Storage the actual source for the existing Resume Reviewer.

Currently the portfolio system stores the canonical resume at:

`resumes/{uid}/latest.pdf`

The existing Resume Reviewer/ATS pipeline should be extended so that the reviewer can consume this uploaded PDF directly.

The unfinished item from the previous cycle was:

**MB7 — PDF → text for Resume Review**

Turn this into the first major task of v8.5.

---

# REQUIRED WORKFLOW

First inspect the existing implementation before modifying anything.

Inspect at minimum:

* `lib/views/resume_review_view.dart`
* `lib/services/ai/resume_review_service.dart`
* `functions/index.js`
* `lib/services/firestore/resume_service.dart`
* `lib/services/storage/storage_service.dart`
* `lib/models/portfolio/resume_metadata.dart`
* `lib/models/portfolio/portfolio_model.dart`
* `lib/providers/portfolio_provider.dart`
* existing resume-review models/services
* existing ATS score persistence
* existing resume review history implementation
* `firestore.rules`
* `storage.rules`
* `docs/todo.md`
* `docs/issues.md`
* `docs/v8_workspace_tracker.md`

Trace the complete current Resume Review data flow before coding.

Do not assume how the current implementation works.

---

# v8.5.1 — Resume Storage → Resume Reviewer

Implement the smallest safe bridge between the uploaded resume and the existing review pipeline.

## Desired flow

Student uploads resume:

`resumes/{uid}/latest.pdf`

↓

Portfolio stores:

* `storagePath`
* `fileName`
* `fileSize`
* `mimeType`
* `uploadedAt`
* `updatedAt`
* existing metadata

↓

Student opens Resume Reviewer

↓

Reviewer detects the current uploaded resume

↓

Client sends the authenticated user's resume `storagePath` to the callable `reviewResume`

↓

Cloud Function:

1. obtains the authenticated UID from `request.auth.uid`
2. validates that the supplied storage path belongs to that UID
3. validates that the path points to the expected resume location
4. downloads the PDF using Firebase Admin SDK
5. extracts readable text from the PDF
6. passes the extracted text through the EXISTING AI/ATS review pipeline
7. returns the existing review result format

Do not bypass existing authentication or callable-function security.

---

# PDF TEXT EXTRACTION

Choose the simplest reliable server-side implementation compatible with the current `functions/package.json`.

Before adding a dependency:

* inspect existing dependencies
* inspect Node/runtime version
* verify compatibility with Firebase Functions
* avoid unnecessarily large or abandoned packages

The extractor must:

* accept PDF data
* extract text from normal text-based PDFs
* gracefully handle empty/unextractable PDFs
* return a useful error instead of crashing
* avoid logging resume contents
* avoid exposing PDF contents to the client unnecessarily

If a PDF is image-only/scanned and cannot be text-extracted, return a clear user-facing message such as:

`This resume appears to be image-based and could not be read automatically. Please upload a text-based PDF.`

Do NOT implement OCR unless the existing architecture already supports it.

---

# SECURITY REQUIREMENTS

This is critical.

The client must NOT be able to review another student's resume simply by supplying another UID/path.

Server-side validation must enforce:

`request.auth.uid === owner UID in storagePath`

Only allow the expected resume path:

`resumes/{uid}/latest.pdf`

Do not trust a client-supplied UID.

Use:

`request.auth.uid`

as the authoritative identity.

Do not expose service-account credentials.

Do not weaken `storage.rules`.

Do not make the Storage bucket publicly readable.

Do not add `allow read: if true`.

Do not log extracted resume text.

---

# v8.5.2 — Resume Review UI Integration

Update `resume_review_view.dart` so the existing reviewer understands the uploaded resume.

If a resume exists, show:

* current resume filename
* upload/version information if already available
* latest ATS score when available
* review count when available
* `Review Uploaded Resume`
* `Open Uploaded Resume`
* `Replace Resume`

The reviewer should use the canonical uploaded resume automatically.

Avoid making the user manually copy/paste resume text when a valid uploaded PDF exists.

---

# FALLBACK BEHAVIOR

If no uploaded resume exists:

Keep the existing text/manual review functionality if it already exists.

Example:

`No uploaded resume found. Upload a PDF to review your current resume, or continue with the existing manual review option.`

Do not remove working functionality simply because the uploaded-resume path was added.

---

# v8.5.3 — ATS / Portfolio Synchronization

Preserve the existing v8.4.2 behavior:

After a successful review, the system must continue updating:

`users/{uid}/portfolio.resume`

with the existing fields:

* `latestATSScore`
* `reviewCount`
* `lastReviewAt`
* `updatedAt`

Do NOT create a duplicate ATS score elsewhere unless the existing architecture already requires it.

The existing dashboard and portfolio components must continue reading the same source of truth.

Verify that:

* Student Dashboard Latest ATS still updates
* Student Portfolio Latest ATS still updates
* Read-only Portfolio ATS still works
* Resume Age remains correct
* Resume Review History remains correct

---

# v8.5.4 — Review History

Inspect the existing review-history implementation.

If it already stores individual review records, reuse it.

Do not create duplicate review collections.

Ensure a review generated from the uploaded PDF appears in the existing review history.

Each review should remain associated with the authenticated student.

Do not overwrite previous review records merely because the resume is replaced.

---

# v8.5.5 — Resume Replacement Behavior

Verify this scenario carefully:

1. Student uploads Resume A.
2. Resume A becomes `resumes/{uid}/latest.pdf`.
3. Student reviews Resume A.
4. ATS score updates.
5. Student replaces the resume with Resume B.
6. Resume B becomes the current resume.
7. Student reviews Resume B.
8. Portfolio now represents Resume B and its latest ATS score.
9. Previous review history remains intact.
10. Existing placement applications retain their immutable resume snapshots.

Do NOT modify historical placement snapshots when the current resume changes.

The placement architecture must remain:

CURRENT RESUME
→ review/portfolio

CURRENT RESUME
→ placement application
→ immutable snapshot

---

# v8.5.6 — Error Handling

Handle at minimum:

* unauthenticated user
* missing resume metadata
* missing Storage file
* invalid storage path
* wrong user's storage path
* non-PDF file
* empty PDF
* unreadable/scanned PDF
* PDF extraction failure
* AI review failure
* network failure
* callable timeout
* malformed AI response

The UI must never remain stuck on a loading spinner.

All loading flags must reset using `finally`.

Provide useful SnackBars/error states without exposing internal exceptions or sensitive data.

---

# v8.5.7 — Testing

Add focused tests for the new behavior.

At minimum test:

### Storage path validation

Valid:

`resumes/USER123/latest.pdf`

Invalid:

`resumes/OTHERUSER/latest.pdf`

Invalid:

`users/USER123/resume.pdf`

Invalid:

`resumes/USER123/other.pdf`

### Resume metadata

Verify the existing `ResumeMetadata` parsing still works.

### Review result persistence

Verify that a successful review produces the expected ATS/portfolio update contract.

### Existing functionality

Run all existing tests.

Do not remove or weaken existing tests.

---

# VALIDATION

Run:

```powershell
flutter analyze
flutter test
```

Also run:

```powershell
node --check functions/index.js
```

If dependencies were changed:

```powershell
cd functions
npm install
cd ..
```

Then deploy only what actually changed.

For example:

```powershell
firebase deploy --only functions
```

Do NOT automatically redeploy unrelated Firestore indexes/rules unless they were modified.

---

# MANUAL TEST MATRIX

After deployment, verify on a real/device build:

### Test 1 — Existing resume

* Login as student
* Open Portfolio
* Confirm current resume exists
* Open Resume Reviewer
* Review uploaded resume
* Confirm ATS result appears

### Test 2 — Dashboard

Confirm:

* Resume Uploaded
* Latest ATS
* Last Review
* Resume Age

remain correct.

### Test 3 — Replace resume

* Upload Resume B
* Confirm Resume B becomes current
* Review Resume B
* Confirm latest ATS changes
* Confirm history remains

### Test 4 — Placement

* Apply for a placement
* Confirm application stores:

  * `resumeVersion`
  * `resumeStoragePath`
  * `atsScoreAtApplication`
* Replace current resume
* Confirm old application snapshot remains unchanged.

### Test 5 — Security

Attempt to access another student's resume through the reviewer/storage path.

It MUST fail.

### Test 6 — Bad PDF

Upload an unreadable/image-only PDF and verify the application shows a friendly error instead of crashing or hanging.

---

# DOCUMENTATION

After implementation update:

## `docs/todo.md`

Create a new:

`v8.5 — Resume Reviewer Integration & PDF Intelligence`

section.

Track each subtask individually:

* R1 — Architecture/data-flow audit
* R2 — PDF extraction
* R3 — Callable integration
* R4 — Resume Reviewer UI
* R5 — ATS/portfolio synchronization
* R6 — Review history
* R7 — Resume replacement verification
* R8 — Error handling
* R9 — Security tests
* R10 — Validation/deployment/manual pass

## `docs/issues.md`

Record any newly discovered issues.

Do not mark an issue fixed unless it is actually verified.

## `docs/v8_workspace_tracker.md`

Add a new v8.5 phase with:

* objective
* architecture
* subtasks
* files changed
* validation
* deployment status
* manual verification status
* known limitations

Update the version number only after the implementation is actually complete.

---

# VERSIONING

Update the Flutter version according to the project's existing versioning convention.

Do not arbitrarily change unrelated version numbers.

---

# IMPORTANT ARCHITECTURE RULES

Preserve:

1. `users/{uid}/portfolio` nested portfolio architecture
2. `resumes/{uid}/latest.pdf`
3. Firebase Storage security rules
4. teacher/alumni read permissions
5. existing ResumeService
6. existing PortfolioService
7. existing PortfolioProvider
8. existing ATS persistence
9. existing placement resume snapshots
10. existing callable authentication
11. existing review history
12. Material 3 UI architecture

Do not refactor unrelated modules.

Do not rewrite working code simply for style.

Prefer small, isolated changes.

---

# FINAL REPORT

When finished, report:

1. What was already working
2. What you changed
3. Exact files changed
4. PDF extraction approach and dependency
5. Security validation
6. ATS/portfolio relationship
7. Placement snapshot verification
8. `flutter analyze` result
9. `flutter test` result
10. `node --check` result
11. Deployment result
12. Manual test result
13. Any remaining limitations
14. Exact next recommended version

Do not claim deployment or manual testing unless it was actually performed.

## PRIMARY SUCCESS CRITERION

A student should be able to:

**Upload Resume → Open Resume Reviewer → Review Uploaded PDF → Receive ATS/AI Review → Portfolio updates → Dashboard updates → Apply to Placement using the current resume → Placement retains an immutable snapshot.**

That complete flow is the definition of v8.5 success.
