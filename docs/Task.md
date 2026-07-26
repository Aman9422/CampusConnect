Yes. At this stage, adding realistic seed data is the best approach. It will allow you to properly validate the Teacher Dashboard, AI Insights, analytics, placement funnel, engagement metrics, and every chart before your final deployment.

Here's a prompt you can use with your coding model:

---

# CampusConnect v8.3 — Firestore Demo Data Seeder

## Objective

Create a comprehensive **demo dataset** for CampusConnect so every dashboard (Student, Alumni, Teacher) can be fully tested with realistic data.

This data is **temporary development/demo data only** and will be deleted before production.

Do NOT modify any existing production logic.

---

## Goals

Populate Firestore with realistic interconnected data so that:

* Teacher Dashboard shows meaningful analytics
* Student Dashboard displays recommendations and engagement
* Alumni Dashboard displays mentorships and opportunities
* AI Insights generates useful summaries
* Resume Analytics has enough data
* Placement Funnel contains realistic values
* Department comparison charts work
* Skill Gap Analysis has sufficient variation

---

# Data Requirements

Create interconnected demo records for:

### Students

Create **30 students**

Each student should contain:

* uid
* fullName
* email
* role = student
* department
* year
* skills
* profileStrength
* createdAt

Departments should include:

* CSE
* AIML
* IT
* AIDS
* ETC

Distribute students across departments.

---

### Alumni

Create **10 alumni**

Each alumni should contain:

* uid
* fullName
* email
* company
* designation
* yearsExperience
* skills
* mentorshipEnabled
* publicProfile
* profileStrength

---

### Teachers

Create **5 teachers**

Include

* department
* designation
* experience
* profile

---

### Resume Reviews

For every student create

3–5 Resume Reviews

Each review should contain

* ATS Score
* Missing Keywords
* Suggestions
* Review Date
* Improvement Notes

Generate realistic ATS values

Example

45
58
67
71
84
91

Include progression so Student Growth charts become meaningful.

---

### Engagement Summary

For every student create

engagement_summary/summary

Include

* engagementScore
* profileStrength
* streak
* completedActions
* badges

Use different values.

---

### Applications

Create

80–120 application documents

Spread among students.

Each application should contain

* userId
* placementId
* appliedAt

Ensure

Applied Students <= Eligible Students

Never count duplicate students incorrectly.

Multiple applications by the same student are allowed.

---

### Placements

Create

20 placement drives

Mix

* Active
* Closed
* Upcoming

Include

company

title

package

deadline

isActive

---

### Opportunities

Create

15 Alumni Opportunities

Mix

Internships

Jobs

Referral Posts

Hackathons

---

### Mentorship Requests

Create

40 mentorship requests

Mix

Pending

Accepted

Completed

Rejected

Connect students and alumni realistically.

---

### Recommendations

Populate

recommendations

collection

Include

Job Recommendations

Mentor Recommendations

Skill Recommendations

Learning Recommendations

---

### Activity Feed

Generate

150+

activities

Examples

Resume reviewed

Profile updated

Placement applied

Mentorship accepted

Badge earned

Opportunity posted

---

### Notifications

Generate

notifications

for

Students

Teachers

Alumni

Use different notification types.

---

## Data Quality Rules

Do NOT generate identical users.

Every student should have

different

skills

ATS scores

profile strength

engagement score

resume history

applications

mentor

recommendations

Departments should have different average ATS scores.

Some students should intentionally be

High performers

Average performers

At-risk students

Inactive students

Highly engaged students

This allows AI analytics to work correctly.

---

## Validation Targets

After seeding:

Teacher Dashboard should show

* Total Students
* Department Comparison
* Resume Analytics
* Skill Gap Analysis
* Placement Funnel
* Student Growth
* At-Risk Students
* AI Summary

without empty states.

Student Dashboard should show

* Recommendations
* Badges
* Engagement
* AI Chat History
* Resume History

Alumni Dashboard should show

* Mentorship Queue
* Opportunities
* Student Requests
* Impact Metrics

---

## Safety

* Create the seed script under a separate folder such as:

```
scripts/seed_firestore/
```

or

```
tools/demo_seed/
```

* Never execute automatically.
* Run only when explicitly invoked.
* Include a matching cleanup script that deletes all seeded demo data.
* Prefix every demo document with a flag like:

```
isDemoData: true
```

or

```
environment: "demo"
```

so cleanup is safe and production data is never accidentally removed.

---

## Deliverables

1. Firebase Admin Node.js seed script
2. Cleanup script
3. README explaining how to run both
4. Progress logging during seeding
5. Validation summary showing how many documents were created in each collection
6. Ensure the entire script is idempotent (safe to rerun without creating duplicate records).
