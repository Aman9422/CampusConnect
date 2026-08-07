# CampusConnect v8.4.1 — Resume Portfolio & Firebase Storage Foundation

## Objective

Implement the complete Resume Portfolio system, making the student's resume the central asset of CampusConnect.

This version establishes the foundation for:

* Resume Reviewer (v8.5)
* Resume Intelligence (v8.6)
* AI Recommendation Engine (v8.7)
* Teacher Analytics 2.0
* Alumni Mentorship Intelligence
* Placement Resume Snapshot

The implementation should be production-ready, modular, and backward-compatible with the existing CampusConnect architecture.

---

# Design Principles

* Do NOT break existing dashboards.
* Do NOT remove any existing ATS review functionality.
* Build on top of the existing architecture.
* Keep Firestore reads optimized.
* Use Firebase Storage for PDF files only.
* Keep all services modular.
* Follow current project naming conventions.
* Use Material 3.
* Maintain dark/light theme compatibility.
* Preserve all role-based permissions.

---

# Phase 1 — Resume Storage

Implement Firebase Storage integration.

Storage path:

resumes/{uid}/latest.pdf

Future-ready structure:

resumes/
uid/
latest.pdf
history/
v1.pdf
v2.pdf

Implement:

* Upload Resume
* Replace Resume
* Download Resume
* Delete Resume
* Upload Progress
* File Validation
* PDF Only
* Maximum 5 MB

---

# Phase 2 — Resume Metadata

Create Firestore metadata document.

Suggested path:

users/{uid}/resume/metadata

Fields:

* uploadedAt
* updatedAt
* storagePath
* downloadUrl
* fileName
* fileSize
* mimeType
* version
* latestATSScore
* reviewCount
* lastReviewAt
* hasResume
* isDemoData (optional)

---

# Phase 3 — Student Resume Portfolio

Create a dedicated Resume Portfolio section.

Portfolio should display:

Personal Information

Education

CGPA

Skills

Projects

Experience

Certifications

Achievements

Languages

GitHub

LinkedIn

Portfolio Website

Preferred Roles

Preferred Locations

Career Objective

Resume Status

Resume Upload Date

Latest ATS Score

Latest Review

Resume Download Button

Replace Resume Button

Delete Resume Button

---

# Phase 4 — Resume Service

Create a reusable ResumeService responsible for:

Upload Resume

Download Resume

Delete Resume

Replace Resume

Read Metadata

Update Metadata

Check Resume Exists

Get Resume URL

Future support for version history

Business logic must remain outside UI widgets.

---

# Phase 5 — Student Dashboard Integration

Replace simple ATS resume card with a Resume Portfolio summary.

Show:

Resume Uploaded

Latest ATS

Resume Age

Last Review

Open Portfolio

Upload / Replace Resume

---

# Phase 6 — Teacher Dashboard

Teachers should be able to:

Open Student Portfolio

View Resume Metadata

Download Resume

View Latest ATS

View Resume Status

No editing permissions.

---

# Phase 7 — Alumni Dashboard

Alumni should be able to:

Open Student Portfolio

Download Resume

View Resume Metadata

No editing permissions.

---

# Phase 8 — Placement Integration

Update placement applications.

Each application must store:

studentId

placementId

resumeVersion

resumeStoragePath

atsScoreAtApplication

appliedAt

status

This preserves the resume used when applying even after future uploads.

---

# Phase 9 — Firestore Security

Ensure:

Students

can upload only their own resumes.

Teachers

can only read resumes.

Alumni

can only read resumes.

No anonymous access.

No public Storage URLs.

---

# Phase 10 — UI

Create a clean Resume Portfolio page.

Sections:

Header

Resume Status Card

Quick Actions

Personal Details

Education

Projects

Skills

Experience

Certifications

Links

Career Preferences

Resume Metadata

Theme must match CampusConnect.

---

# Phase 11 — Architecture

Create (or update) modular components as needed:

Models

ResumeMetadata

ResumePortfolio

Services

ResumeService

StorageService

Providers

ResumeProvider

Widgets

ResumeCard

ResumeMetadataCard

ResumeActions

ResumeUploadDialog

ResumeStatusChip

Views

ResumePortfolioView

---

# Phase 12 — Validation

Ensure:

flutter analyze

returns

0 errors

0 warnings

Verify:

✔ Upload works

✔ Replace works

✔ Download works

✔ Delete works

✔ Metadata updates

✔ Teachers can read

✔ Alumni can read

✔ Students cannot access others' resumes

✔ Existing ATS Review remains functional

✔ Existing dashboards continue working

✔ Existing analytics are unaffected

---

# Out of Scope

Do NOT implement in v8.4:

Resume parsing

AI resume suggestions

Resume version history UI

Resume reviewer changes

AI recommendations

Teacher analytics improvements

Admin dashboard

These belong to later roadmap versions.

---

# Expected Outcome

CampusConnect should now have a centralized Resume Portfolio system backed by Firebase Storage and Firestore metadata.

The resume becomes the single source of truth for:

* Resume Reviewer (v8.5)
* Resume Intelligence (v8.6)
* AI Recommendation Engine (v8.7)
* Placement applications
* Teacher analytics
* Alumni mentorship

The implementation must prioritize maintainability, scalability, and compatibility with future roadmap versions.
