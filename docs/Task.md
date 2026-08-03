You are the lead Flutter + Firebase architect for my production-level project called CampusConnect.

IMPORTANT:
This project already exists. Do NOT redesign the application.
Do NOT change existing architecture.
Do NOT break existing features.

Current stack:
- Flutter
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Provider state management
- Material 3
- Existing Student, Teacher and Alumni dashboards
- Existing ATS Resume Review system
- Existing AI Assistant
- Existing Firestore models and services

Current version:
CampusConnect v8.3
Completed:
✔ Teacher Dashboard
✔ Teacher Analytics
✔ AI Insights
✔ Firestore Demo Data Seeder

Now implement ONLY version v8.4.

=========================================================
VERSION 8.4
Student Resume Portfolio
=========================================================

Goal:

Transform every student profile into a complete professional portfolio.

The portfolio should become the foundation for future AI recommendations and mentorship matching.

DO NOT implement AI recommendations yet.

=========================================================
FEATURES
=========================================================

1. Resume Upload

Students can upload a Resume PDF.

Store files inside Firebase Storage.

Example:

resumes/{uid}/resume.pdf

Store metadata in Firestore.

Resume metadata should include:

- downloadUrl
- uploadDate
- lastUpdated
- version
- ATS Score
- parserVersion

=========================================================

2. Portfolio Model

Create a proper Dart model.

Example fields:

resume

skills

projects

certifications

experience

education

achievements

socialLinks

preferences

=========================================================

3. Skills

Allow multiple skills.

Each skill should include:

- name
- category
- proficiency

Proficiency:

Beginner

Intermediate

Advanced

=========================================================

4. Projects

Students can add multiple projects.

Each project contains:

title

description

technologies

githubUrl

demoUrl

startDate

endDate

currentlyWorking

=========================================================

5. Certifications

Store:

title

issuer

issueDate

credentialId

credentialUrl

=========================================================

6. Experience

Store:

company

role

employmentType

description

startDate

endDate

currentlyWorking

=========================================================

7. Education

Store:

college

department

program

semester

cgpa

graduationYear

=========================================================

8. Social Links

Store:

GitHub

LinkedIn

Portfolio

LeetCode

Codeforces

HackerRank

=========================================================

9. Career Preferences

Store:

preferredRoles

preferredLocations

expectedSalary

remotePreference

relocationPreference

=========================================================

10. Achievements

Allow multiple achievements.

Each achievement contains:

title

description

date

category

=========================================================
UI
=========================================================

Create clean Material 3 pages.

Do NOT redesign the app.

Only add:

Student Portfolio Screen

Edit Portfolio Screen

Projects Manager

Certifications Manager

Experience Manager

Resume Upload

Portfolio Preview

Teacher Read-only Portfolio View

Alumni Read-only Portfolio View

Reuse existing design language.

=========================================================
FIRESTORE
=========================================================

Use the existing users collection.

Store portfolio under each student document.

Example:

users/{uid}

portfolio

resume

projects

experience

certifications

skills

preferences

links

achievements

Keep everything compatible with the current Firestore structure.

=========================================================
SERVICES
=========================================================

Create:

PortfolioService

StorageService for Resume Upload

PortfolioProvider

PortfolioModel

ProjectModel

CertificationModel

ExperienceModel

AchievementModel

Do not duplicate existing services.

=========================================================
VALIDATION
=========================================================

Validate:

Required fields

PDF upload only

Maximum resume size

Valid URLs

Prevent duplicate skills

Prevent empty projects

=========================================================
SECURITY
=========================================================

Update Firestore Rules.

Only owner can edit portfolio.

Teachers

Alumni

Admin

have read-only access.

=========================================================
CODE QUALITY
=========================================================

Follow existing architecture.

Use Provider.

Keep code modular.

Avoid duplicate code.

Add documentation.

Maintain production-quality code.

=========================================================
OUT OF SCOPE
=========================================================

Do NOT implement:

AI Recommendation Engine

Mentorship AI

Resume Parsing

Resume History

Resume Versioning

Notification System

Admin Dashboard

Analytics Changes

Those belong to future versions.

=========================================================
EXPECTED OUTPUT
=========================================================

Implement the complete CampusConnect v8.4 Student Resume Portfolio feature while preserving all existing functionality.