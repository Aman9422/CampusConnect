# CampusConnect v8.3 — Firestore Demo Data Seeder

Populates your Firebase project with **realistic interconnected demo data** for every CampusConnect dashboard — Teacher, Student, and Alumni.

## What Gets Seeded

| Dataset | Count | Purpose |
|---------|-------|---------|
| Students | 30 | 5 depts (CSE, AIML, IT, AIDS, ETC), varied performance profiles |
| Alumni | 10 | Google, Microsoft, Amazon, Flipkart, etc. |
| Teachers | 5 | One per department |
| Resume Reviews | 120-150 | 3-5 per student with **progressive ATS scores** |
| Engagement Summaries | 30 | Per student with badges, streaks, scores |
| Placements | 20 | Active, Closed, Upcoming — real companies |
| Applications | 80-120 | Spread across students (both data paths) |
| Mentorship Requests | 40 | Pending/Accepted/Completed/Rejected |
| Opportunities | 15 | Internships, Jobs, Referrals, Hackathons |
| Chats + Messages | 22 chats | For accepted mentorships, 3-10 messages each |
| Notifications | ~200 | Students, Alumni, Teachers — varied types |
| Activities | 150+ | Login, resume review, application, etc. |
| Recommendations | 6 per student | Mentor, Job, Skill, Chat recommendations |
| AI Interactions | ~75 | Chat history for every other student |
| Public Profiles | 6 | Shareable alumni profile projections |

## Performance Profiles

Students are intentionally differentiated for realistic analytics:

| Type | Count | Characteristics |
|------|-------|----------------|
| **High Performers** | 3 | ATS 82-95, CGPA 8.0-9.5, high engagement |
| **Average Performers** | 15 | ATS 50-75, moderate skills and engagement |
| **At-Risk Students** | 5 | ATS 25-48, low CGPA, few skills |
| **Inactive Students** | 3 | Few reviews, zero engagement, no apps |
| **Highly Engaged** | 4 | High streaks, many badges, many applications |

Differential department performance:
- **CSE**: Highest avg ATS (65-78)
- **AIML**: Mid-high avg ATS (60-72)
- **IT**: Mid avg ATS (55-68)
- **AIDS**: Mid-low avg ATS (48-60)
- **ETC**: Lowest avg ATS (40-55)

## Prerequisites

- **Node.js 18+**
- A **Firebase service account key** with Firestore write access
- The Firebase project must already have Firestore initialized

## Setup

### 1. Get your service account key

1. Go to [Firebase Console](https://console.firebase.google.com/) → Project Settings → Service Accounts
2. Click **"Generate New Private Key"**
3. Save the downloaded JSON file as `scripts/seed_firestore/serviceAccountKey.json`

> ⚠️ **Security**: Never commit `serviceAccountKey.json` to version control. It's already in `.gitignore` if you add the seed directory pattern.

### 2. Install dependencies

```bash
cd scripts/seed_firestore
npm install
```

## Usage

### Seed the database

```bash
cd scripts/seed_firestore
npm run seed
```

The script will:
1. Log progress for each phase
2. Use batched writes in chunks of 490 (Firestore batch limit)
3. Print a validation summary when complete
4. Flag every document with `isDemoData: true` and `environment: "demo"`

Expected runtime: **2-5 minutes** depending on your network and Firestore location.

### Clean up demo data

```bash
cd scripts/seed_firestore
npm run cleanup
```

The cleanup script:
1. Finds ALL documents with `isDemoData: true`
2. Deletes subcollections first (messages, applications, resumeReviews, etc.)
3. Deletes parent documents (users, placements, chats, etc.)
4. Prints a summary of what was deleted

**Safety**: Only documents with the `isDemoData` flag are touched. Production data without this flag is NEVER affected.

## Idempotency

The seed script is **safe to re-run**. Each run creates new document IDs (for subcollections) or overwrites existing demo documents with `SetOptions({merge: false})`. To completely re-seed:

```bash
npm run cleanup  # Delete all demo data
npm run seed     # Re-create from scratch
```

## Architecture

```
scripts/seed_firestore/
├── package.json          # npm scripts: seed, cleanup
├── seed.js               # Main seed script (14 phases)
├── cleanup.js            # Cleanup script (7 phases)
├── README.md             # This file
├── serviceAccountKey.json # YOUR Firebase service account key (NOT committed)
└── .gitignore            # Ignore serviceAccountKey.json
```

### Data Flow

The seed script creates documents in **14 sequential phases**:

```
Phase  1: Users (students → alumni → teachers)
Phase  2: Resume Reviews (3-5 per student, progressive scores)
Phase  3: Engagement Summaries (one per student)
Phase  4: Placements (20 drives, mixed status)
Phase  5: Applications (80-120, dual paths)
Phase  6: Mentorship Requests (40, all statuses)
Phase  7: Opportunities (15, mixed types)
Phase  8: Chats + Messages (22 chats, 3-10 messages each)
Phase  9: Notifications (~200, all user types)
Phase 10: Activities (150+, varied events)
Phase 11: Recommendations (6 per student)
Phase 12: AI Interactions (~75)
Phase 13: Public Profiles (6 alumni)
Phase 14: Recommendations Meta (30 documents)
```

### Dual Application Paths

The seed writes applications to **both**:
- `placements/{placementId}/applications/{uid}` (newer, primary)
- `applications/{applicationId}` (legacy, global index)

This ensures backward compatibility with both old and new code paths.

## Validation Targets

After seeding, verify that:

### Teacher Dashboard
- Total Students: **30**
- Department Comparison: **5 departments with different avg scores**
- Resume Analytics: **120-150 reviews, avg score varies by dept**
- Skill Gap Analysis: **20+ missing keywords detected**
- Placement Funnel: **30 eligible, 20-25 applied**
- Student Growth: **ATS progression visible per student**
- At-Risk Students: **5 flagged**
- AI Summary: **Non-empty narrative**

### Student Dashboard
- Recommendations: **6 per student (mentor, job, skill, chat)**
- Badges: **Based on streak/engagement**
- Engagement: **30-98 score range**
- AI Chat History: **2-5 interactions per student**
- Resume History: **3-5 reviews per student**

### Alumni Dashboard
- Mentorship Queue: **10 pending, 12 accepted, 10 completed**
- Opportunities: **15 posted**
- Student Requests: **Varied states**
- Impact Metrics: **Active counts visible**

## Troubleshooting

| Problem | Likely Cause | Solution |
|---------|-------------|----------|
| `Error: Cannot find module 'firebase-admin'` | Dependencies not installed | Run `npm install` |
| `Error: Could not load service account` | Missing `serviceAccountKey.json` | Download key from Firebase Console |
| `PERMISSION_DENIED` | Service account lacks Firestore write access | Ensure Firestore is initialized in your project |
| `Error: 13 INTERNAL` | Rate limit / batch too large | Script automatically batches at 490 writes |
| Seed succeeds but dashboard still shows 0 | App pointing to different Firebase project | Verify `lib/firebase_options.dart` matches your seed project |
| Cleanup takes too long | Many documents to scan | Normal — Firestore queries all docs with the flag |
