# CampusConnect
### AI-Powered Smart Campus Ecosystem for Student and Alumni Collaboration and Career Growth

CampusConnect is a Flutter-based smart campus application designed to connect students, alumni, and teachers through a unified digital platform. It brings together academic resources, career opportunities, placement support, communication, and AI-powered career assistance.

The platform provides role-based experiences and uses Firebase services for authentication, data management, file storage, and backend operations. AI capabilities are integrated through secure backend services to support students with career guidance and resume evaluation.

## Table of Contents

- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [User Roles](#user-roles)
- [AI-Powered Capabilities](#ai-powered-capabilities)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Testing and Verification](#testing-and-verification)
- [Security](#security)
- [Project Documentation](#project-documentation)
- [Current Project Status](#current-project-status)
- [Developer](#developer)

## Project Overview

CampusConnect aims to improve collaboration between students, alumni, and teachers by providing a centralized platform for academic and professional development.

The application includes features such as:

- Academic notes and learning resources.
- Student and alumni networking.
- Placement and career opportunities.
- Resume evaluation and career guidance using AI.
- Communication and collaboration tools.
- Role-based dashboards and analytics.

The application is developed using Flutter and Firebase, with AI processing handled through backend Cloud Functions rather than exposing API credentials in the client application.

## Key Features

### Academic Resources
- Upload, access, and download academic notes.
- Organize and share learning materials.
- Access resources through the application.

### Placement and Career Opportunities
- Explore available placement and career opportunities.
- Apply for eligible opportunities.
- Track application status.
- Prevent duplicate applications through backend validation.

### Student and Alumni Networking
- Discover alumni profiles.
- Connect with alumni and other members.
- Support mentorship and professional networking.
- Share career-related opportunities.

### Communication
- In-app messaging and chat functionality.
- Notifications for relevant application activities.
- Communication between members of the campus community.

### Student Resume Portfolio
- Maintain a student resume portfolio.
- Present academic and professional information.
- Allow authorized teachers to review student portfolios.

### Teacher Dashboard and Analytics
- Access student-related information.
- Review student resumes.
- View student analytics and performance-related information.
- Access portfolio information through authorized routes.

## User Roles

CampusConnect provides role-based functionality for different members of the academic community.

| Role | Main Responsibilities and Features |
|---|---|
| Student | Access notes, explore opportunities, apply for placements, manage resume portfolio, use AI career tools, and communicate with other members. |
| Alumni | Maintain professional profiles, connect with students, share opportunities, and support mentorship activities. |
| Teacher | Manage academic and career-related activities, review student portfolios, and access student analytics. |
| Admin | Access administrative functionality and manage platform-level operations. |

Access to application features is controlled through role-based authorization.

## AI-Powered Capabilities

CampusConnect integrates AI functionality through Firebase Cloud Functions.

### AI Assistant
Provides an AI-powered conversational interface to help users with relevant academic and career-related queries.

### Resume Review
The resume review functionality evaluates uploaded resumes and provides structured feedback, including:

- ATS-style score estimation.
- Resume strengths.
- Missing or relevant keywords.
- Formatting observations.
- Suggestions for improving resume bullet points.
- Recommendations for resume sections.

The generated score is an AI-based estimate and should not be interpreted as an actual score from a specific applicant tracking system.

### AI Career Coach
Provides AI-generated career guidance and recommendations based on available student information and career-related context.

### AI Provider Integration

The backend uses a provider integration strategy:

- Groq as the primary AI provider.
- Hugging Face as the fallback provider.
- Model configuration includes `openai/gpt-oss-20b`.

AI requests are processed through backend Cloud Functions. Provider API keys are stored in backend configuration and are not embedded in the Flutter application.

## Technology Stack

| Category | Technologies |
|---|---|
| Frontend | Flutter, Dart |
| State Management | Provider |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| File Storage | Firebase Storage |
| Backend | Firebase Cloud Functions |
| Backend Runtime | Node.js 22 |
| Backend SDK | Firebase Admin SDK |
| AI Integration | Groq, Hugging Face |
| Resume Processing | PDF parsing |
| Notifications | Firebase Cloud Messaging |
| Security | Firebase Security Rules, Firebase App Check configuration |
| Data Visualization | FL Chart |
| Version Control | Git and GitHub |

## System Architecture

The application follows a client-server architecture with Firebase services handling authentication, data storage, and backend operations.

```text
                 CampusConnect Application
                    Flutter / Dart
                          |
             ---------------------------
             |            |            |
        Authentication  Firestore   Firebase Storage
             |            |            |
             ---------------------------
                          |
                 Firebase Cloud Functions
                          |
              --------------------------
              |            |           |
          AI Services   Validation   Backend Logic
              |
        ---------------------
        |                   |
       Groq             Hugging Face
     (Primary)           (Fallback)
```

The Flutter application communicates with Firebase services, while sensitive backend operations and AI provider requests are handled through Cloud Functions.

## Project Structure

The following is a high-level overview of the repository organization.

```text
CampusConnect/
|
|-- android/
|-- ios/
|-- assets/
|-- lib/
|   |-- models/
|   |-- providers/
|   |-- services/
|   |-- views/
|   |-- widgets/
|   |
|   |-- main.dart
|
|-- functions/
|   |-- index.js
|   |-- package.json
|   |-- test/
|
|-- docs/
|   |-- Task.md
|   |-- confirmation.md
|   |-- eligibility_rules.md
|   |-- v9_2_4_hardening_report.md
|
|-- test/
|-- firebase.json
|-- firestore.rules
|-- firestore.indexes.json
|-- storage.rules
|-- pubspec.yaml
|-- README.md
```

## Getting Started

Follow these steps to set up the project locally.

### Prerequisites

Install the following tools:

- Flutter SDK
- Dart SDK
- Android Studio or Visual Studio Code
- Node.js 22
- Firebase CLI
- Git

A configured Firebase project is also required.

### 1. Clone the Repository

```bash
git clone https://github.com/Aman9422/CampusConnect.git
```

Navigate to the project directory:

```bash
cd CampusConnect
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Configure Firebase for your own Firebase project using FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Ensure the Firebase configuration files and project settings match your Firebase project.

### 4. Configure Backend Dependencies

Navigate to the Cloud Functions directory:

```bash
cd functions
npm install
```

Configure the required AI provider credentials securely using Firebase Functions secrets or the configuration mechanism specified by the backend implementation.

Do not commit API keys or other sensitive credentials to the repository.

### 5. Deploy Firebase Configuration

From the project root, deploy the required Firebase resources:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Deploy Cloud Functions:

```bash
firebase deploy --only functions
```

### 6. Run the Application

Return to the project root:

```bash
cd ..
```

Check connected devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

## Testing and Verification

CampusConnect has undergone functional, backend, security-rule, and physical-device verification.

The documented v9.2.4 hardening report records the following automated test results:

| Test Area | Result |
|---|---:|
| Flutter Tests | 540 passed |
| Cloud Functions Tests | 97 passed |
| Firestore Security Rule Tests | 37 passed |
| Firebase Storage Rule Tests | 18 passed |
| Total Security Rule Assertions | 55 passed |
| Flutter Static Analysis | No issues reported |

In addition to automated testing, the application has been run and verified on physical devices. The implemented features have been tested and are working as expected.

## Security

Security is an important part of the CampusConnect architecture.

The project incorporates:

- Firebase Authentication for user authentication.
- Role-based access control for application functionality.
- Firestore Security Rules for database access restrictions.
- Firebase Storage Security Rules for file access restrictions.
- Backend validation through Cloud Functions.
- Server-side handling of AI provider credentials.
- Firebase App Check configuration.

App Check enforcement settings should be reviewed according to the deployment environment and distribution requirements. Do not assume that configuration alone means enforcement is enabled.

## Project Documentation

Additional technical information is available in the repository:

| Document | Description |
|---|---|
| `CHANGELOG.md` | Project version history and feature updates. |
| `docs/Task.md` | Development requirements and implementation tasks. |
| `docs/confirmation.md` | Project verification and release confirmation. |
| `docs/v9_2_4_hardening_report.md` | Security hardening and testing report. |
| `docs/eligibility_rules.md` | Eligibility and access-related rules. |
| `docs/app_check_status.md` | Firebase App Check configuration status. |

## Current Project Status

CampusConnect is a developed and tested application.

- Core application functionality implemented.
- Student, alumni, and teacher experiences implemented.
- AI-powered career and resume features integrated.
- Firebase backend and security rules configured.
- Automated testing completed with documented results.
- Application successfully tested on physical devices.
- Implemented features verified to be working properly.

Google Play Store publication is a separate distribution step and is not implied by physical-device verification.

## Developer

Aman Yadav

B.Tech – Computer Science and Engineering  
J D College of Engineering and Management, Nagpur

GitHub: [Aman9422](https://github.com/Aman9422)

Project Repository: [CampusConnect](https://github.com/Aman9422/CampusConnect)

---

*CampusConnect — Connecting students, alumni, and educators through technology, collaboration, and AI-powered career development.*
