# 🎓 CampusConnect – AI-Powered Smart Campus App

CampusConnect is a **Flutter + Firebase based smart campus mobile application** designed to centralize academic resources, placement information, and intelligent assistance for college students.

The project follows **clean architecture**, **secure backend practices**, and a **versioned MVP approach**, making it scalable for future AI and alumni-network features.

---

## 🚀 Features (Version 1 – Stable)

### 🔐 Authentication

* Email & password authentication using Firebase
* Email verification enforced
* Secure login / logout flow
* Clean separation using AuthService abstraction

### 🏠 Home Dashboard

* Personalized greeting
* Quick access to core modules
* Latest placement preview
* Modern card-based UI

### 📚 Notes Module

* Real-time academic notes from Firestore
* Subject and year based categorization
* Clean list UI with badges
* Empty and loading states handled

### 💼 Placements Module

* Real-time placement listings
* Deadline tracking with status indicators
* Application structure prepared
* Clean, readable placement cards

### 🤖 AI Chat (UI Ready)

* Dedicated AI chat screen
* Message input and conversation layout
* Backend integration planned for next version

### 🎨 UI / UX

* Material 3 design system
* Modern blue color theme
* Responsive layouts
* Error and empty state handling

---

## 🛠️ Tech Stack

**Frontend**

* Flutter (Dart)
* Material 3

**Backend**

* Firebase Authentication
* Cloud Firestore
* Firebase Core

**Architecture**

* Service-based abstraction
* Clean separation of UI and backend logic
* Versioned development approach

---

## 📂 Project Structure (High Level)

* `lib/`

  * `services/` → Auth & Firestore services
  * `models/` → Data models (Note, Placement)
  * `views/` → UI screens
  * `constants/` → Routes & constants
* `test/` → Authentication tests
* `firebase_options.dart` → Firebase configuration

---

## ▶️ How to Run the Project (Execution Steps)

### 1️⃣ Prerequisites

Make sure you have:

* Flutter SDK installed
* Android Studio / VS Code
* A Firebase account

Check Flutter:

```bash
flutter doctor
```

---

### 2️⃣ Clone the Repository

```bash
git clone https://github.com/<your-username>/campusconnect.git
cd campusconnect
```

---

### 3️⃣ Install Dependencies

```bash
flutter pub get
```

---

### 4️⃣ Firebase Setup

1. Create a Firebase project
2. Enable **Email/Password Authentication**
3. Enable **Cloud Firestore** (Production mode)
4. Add Android / iOS app in Firebase
5. Download config files:

   * `google-services.json` (Android)
   * `GoogleService-Info.plist` (iOS)
6. Place them in the correct platform folders

---

### 5️⃣ Firestore Security Rules (Required)

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /notes/{noteId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    match /placements/{placementId} {
      allow read: if request.auth != null;
      allow write: if false;

      match /applications/{userId} {
        allow read, write: if request.auth != null
                           && request.auth.uid == userId;
      }
    }
  }
}
```

---

### 6️⃣ Add Sample Firestore Data

Create collections:

* `notes`
* `placements`

Add sample documents so the UI can display real-time data.

---

### 7️⃣ Run the App

```bash
flutter run
```

---

## ✅ Version 1 Status

* ✅ Authentication complete
* ✅ Firestore integration complete
* ✅ Notes & placements working
* ✅ Secure backend rules
* ✅ Stable release tagged as `v1.0.0`

---

## 🔮 Roadmap

### Version 2

* Placement apply functionality
* Note file downloads
* UI/UX polish
* Advanced filters and search

### Version 3

* AI Chat backend (Cloud Functions)
* Alumni role & networking
* Resume upload & analysis
* Smart notifications

### ✨ Version 5.0 (Current - January 2026)

#### 🎯 Major Improvements
- **Provider State Management** - Centralized, predictable state for placements and AI
- **Optimistic UI Updates** - Instant feedback (<100ms) when applying for placements
- **90% Firestore Read Reduction** - One-time fetch vs constant streams
- **Idempotent Cloud Functions** - Safe duplicate prevention via transactions
- **Skeleton Loaders** - Polished loading states instead of spinners
- **Applied Date Display** - "Applied • Jan 18" with full timestamp tracking

#### 📂 New Architecture
```
lib/
├── providers/              # NEW - State management layer
│   ├── placements_provider.dart
│   └── ai_usage_provider.dart
├── widgets/                # NEW - Reusable components
│   ├── skeleton_loader.dart
│   └── empty_state.dart
└── models/
    └── application.dart    # NEW - Normalized application model
```

#### 🔒 Security Enhancements
- UID from Firebase Auth (request.auth.uid) - cannot be spoofed
- HTTPS Callable Cloud Functions with automatic auth
- Transaction-based duplicate checking
- Idempotent apply operations

#### 📊 Performance Metrics
| Metric | v4.0.1 | v5.0.0 | Improvement |
|--------|--------|--------|-------------|
| Apply Response | 1-2s | <100ms | 10-20x faster |
| Firestore Reads | ~50/session | ~5/session | 90% reduction |
| Duplicate Applies | Possible | Prevented | 100% safe |

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

---

## 📌 Versioning

* **v1.0.0** – Stable MVP (initial release)
* **v4.0.1** – AI Assistant + HTTPS Callable
* **v5.0.0** – Provider state management + UX polish (current)
* Future versions developed in feature branches


## 👨‍💻 Author

**Aman Yadav**
B.Tech (CSE), 3rd Year
J D College Of Engineering & Management


## ⭐ Support

If you find this project useful, consider giving it a ⭐ on GitHub.

