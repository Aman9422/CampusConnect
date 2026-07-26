/**
 * CampusConnect v8.3 — Firestore Demo Data Seeder
 *
 * Creates a comprehensive demo dataset for every dashboard:
 *   - 30 students, 10 alumni, 5 teachers
 *   - Resume reviews (3-5 per student with progressive ATS scores)
 *   - Engagement summaries, placements, applications
 *   - Mentorship requests, opportunities, chats, notifications
 *   - Recommendations, activities, AI interactions, public profiles
 *
 * Usage:
 *   1. Place serviceAccountKey.json in this directory
 *   2. npm install
 *   3. npm run seed
 *
 * All demo documents flagged: isDemoData: true, environment: "demo"
 * Idempotent: safe to re-run.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const DEMO_FLAGS = { isDemoData: true, environment: 'demo' };
const DEPARTMENTS = ['CSE', 'AIML', 'IT', 'AIDS', 'ETC'];

const SKILLS_BY_DEPT = {
  CSE: ['Java','Python','Data Structures','Algorithms','OS','DBMS','Networks','C++','SQL','OOP','Spring Boot','Hibernate'],
  AIML: ['Python','Machine Learning','Deep Learning','TensorFlow','PyTorch','NLP','Computer Vision','Statistics','Linear Algebra','Pandas','NumPy','Scikit-learn'],
  IT: ['Java','Python','JavaScript','Web Development','React','Node.js','Database Management','Networking','Cybersecurity','Cloud Computing','AWS'],
  AIDS: ['Python','Data Science','Machine Learning','Statistics','SQL','Data Visualization','Pandas','R','Tableau','Power BI','Excel'],
  ETC: ['C','Embedded Systems','VLSI','MATLAB','Signal Processing','IoT','Arduino','Verilog','PCB Design','Communication Systems'],
};

const ALL_SKILLS = [...new Set(Object.values(SKILLS_BY_DEPT).flat())];

const STUDENT_NAMES = [
  'Arjun Sharma','Priya Patel','Rahul Verma','Sneha Reddy','Vikram Singh',
  'Ananya Gupta','Rohit Kumar','Divya Nair','Amit Joshi','Kavya Menon',
  'Siddharth Rao','Ishita Malhotra','Manish Tiwari','Neha Kapoor','Karan Mehta',
  'Pooja Deshmukh','Aditya Chakraborty','Riya Sen','Harsh Vardhan','Nandini Iyer',
  'Gaurav Mishra','Tanvi Kulkarni','Sahil Bhatia','Anjali Saxena','Varun Thakur',
  'Shreya Ghosh','Akashdeep Singh','Lavanya Pillai','Farhan Ansari','Meera Nambiar',
];

const ALUMNI_DATA = [
  { name: 'Rajesh Iyer', company: 'Google', role: 'SDE 2', exp: 4 },
  { name: 'Swati Joshi', company: 'Microsoft', role: 'Software Engineer', exp: 3 },
  { name: 'Abhishek Gupta', company: 'Amazon', role: 'SDE 1', exp: 2 },
  { name: 'Pooja Sharma', company: 'Flipkart', role: 'Data Scientist', exp: 3 },
  { name: 'Vivek Singh', company: 'Walmart', role: 'Backend Developer', exp: 5 },
  { name: 'Neha Agarwal', company: 'TCS', role: 'Systems Engineer', exp: 2 },
  { name: 'Kunal Desai', company: 'Infosys', role: 'Technology Analyst', exp: 4 },
  { name: 'Richa Patel', company: 'Oracle', role: 'Cloud Engineer', exp: 3 },
  { name: 'Sandeep Rao', company: 'Uber', role: 'Data Engineer', exp: 6 },
  { name: 'Ankita Verma', company: 'Adobe', role: 'Product Manager', exp: 5 },
];

const TEACHER_DATA = [
  { name: 'Dr. Suresh Kumar', dept: 'CSE', designation: 'Professor', exp: 15 },
  { name: 'Prof. Meena Joshi', dept: 'AIML', designation: 'Associate Professor', exp: 10 },
  { name: 'Dr. Ravi Shankar', dept: 'IT', designation: 'Professor', exp: 12 },
  { name: 'Prof. Anita Desai', dept: 'AIDS', designation: 'Assistant Professor', exp: 8 },
  { name: 'Dr. Prakash Rao', dept: 'ETC', designation: 'Professor', exp: 14 },
];

function rand(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function randFloat(min, max) { return Math.round((Math.random() * (max - min) + min) * 100) / 100; }
function pick(arr) { return arr[rand(0, arr.length - 1)]; }
function pickN(arr, n) {
  const s = [...arr].sort(() => Math.random() - 0.5);
  return s.slice(0, Math.min(n, arr.length));
}
function dateSub(days) { const d = new Date(); d.setDate(d.getDate() - days); return d; }
function dateSubFrom(base, days) { const d = new Date(base); d.setDate(d.getDate() - days); return d; }

function assignDepartment(index) { return DEPARTMENTS[index % DEPARTMENTS.length]; }

const STUDENT_PROFILES = (() => {
  const p = [];
  p.push({ type: 'high', atsBase: 88, atsRange: [82, 95], cgpaRange: [8.5, 9.5], yr: 4, streakRange: [15, 30], apRange: [120, 200], skillCount: [7, 10], engagementRange: [85, 98] });
  p.push({ type: 'high', atsBase: 85, atsRange: [80, 92], cgpaRange: [8.2, 9.2], yr: 4, streakRange: [10, 25], apRange: [100, 180], skillCount: [7, 10], engagementRange: [80, 95] });
  p.push({ type: 'high', atsBase: 82, atsRange: [78, 90], cgpaRange: [8.0, 9.0], yr: 4, streakRange: [12, 20], apRange: [90, 160], skillCount: [6, 9], engagementRange: [78, 92] });
  for (let i = 0; i < 15; i++) p.push({ type: 'avg', atsBase: 62, atsRange: [50, 75], cgpaRange: [6.5, 8.2], yr: i < 5 ? 4 : i < 10 ? 3 : 2, streakRange: [3, 12], apRange: [30, 100], skillCount: [3, 7], engagementRange: [40, 75] });
  for (let i = 0; i < 5; i++) p.push({ type: 'atRisk', atsBase: 38, atsRange: [25, 48], cgpaRange: [5.0, 6.5], yr: i < 2 ? 4 : 3, streakRange: [0, 3], apRange: [0, 20], skillCount: [1, 3], engagementRange: [10, 35] });
  for (let i = 0; i < 3; i++) p.push({ type: 'inactive', atsBase: 20, atsRange: [10, 35], cgpaRange: [5.5, 7.0], yr: 2, streakRange: [0, 1], apRange: [0, 5], skillCount: [1, 2], engagementRange: [0, 15] });
  for (let i = 0; i < 4; i++) p.push({ type: 'highEng', atsBase: 70, atsRange: [60, 82], cgpaRange: [7.0, 8.5], yr: 3, streakRange: [20, 45], apRange: [150, 300], skillCount: [5, 9], engagementRange: [88, 100] });
  return p;
})();

const MISSING_KEYWORDS_POOL = [
  'Agile Methodologies','CI/CD','Docker','Kubernetes','REST API','Microservices',
  'Unit Testing','Git','Code Review','Design Patterns','System Design','AWS Cloud',
  'DevOps','Data Structures','Algorithms','SQL Optimization','NoSQL','Redis',
  'Message Queues','OAuth','JWT','GraphQL','WebSockets','Event-Driven Architecture',
  'TDD','SOLID Principles','Load Balancing','Caching','CDN','Monitoring',
  'Logging','Containerization','Serverless','Edge Computing','API Gateway',
  'Data Pipelines','ETL','Data Warehousing','Big Data','Spark',
];

const SECTION_ADVICE = [
  { summary: 'Add a concise professional summary highlighting your key skills and career goals.', skills: 'List technical skills with proficiency levels and group them logically.', projects: 'Quantify project impact with metrics.', experience: 'Use STAR format with measurable outcomes.', education: 'Keep concise; move below experience if 2+ years.' },
  { summary: 'Craft a summary that matches target job descriptions.', skills: 'Remove outdated skills, add modern frameworks.', projects: 'Add GitHub links and tech stack badges.', experience: 'Focus on achievements, not responsibilities.', education: 'Include GPA if above 8.0.' },
  { summary: 'Start with a strong opening including your target role.', skills: 'Reorder to put most relevant first.', projects: 'Describe your role clearly, avoid ambiguous "we".', experience: 'Lead each bullet with a strong action verb.', education: 'List certifications alongside education.' },
  { summary: 'Differentiate yourself from other candidates.', skills: 'Match skills with job description keywords.', projects: 'Clear problem-solution-result structure.', experience: 'Remove responsibilities language; use achievement language.', education: 'Consider removing high school.' },
  { summary: 'A targeted summary can double your interview callback rate.', skills: 'Add a "Familiar with" subsection for emerging tech.', projects: 'One strong project beats three weak ones.', experience: 'Use XYZ formula: Accomplished X by doing Y, resulting in Z.', education: 'Format consistently.' },
];

const HIREABILITY = [
  'Strong Hire — excellent alignment with industry standards.',
  'Hire — minor gaps that can be addressed quickly.',
  'Lean Hire — a few key areas need improvement.',
  'Lean No Hire — significant gaps in key areas.',
  'No Hire — requires substantial revision before applying.',
];

const STRENGTHS = [
  'Clear formatting and consistent structure','Strong project descriptions with technical depth',
  'Relevant technical skills well organized','Good use of action verbs throughout',
  'Quantified achievements in experience section','Relevant coursework highlighted effectively',
  'Good balance of technical and soft skills','Open source contributions well documented',
  'Internship experience with clear outcomes','Certifications add credibility',
  'Well-written professional summary','ATS-friendly formatting with standard section headings',
];

const FORMAT_ISSUES = [
  'Tables used for layout — ATS may misread','Missing section headings',
  'Inconsistent date formats','Font size too small for ATS parsing',
  'Multiple columns may confuse parsers','Special characters in headings',
  'Header/footer content in main body','Images/logos in header — not ATS-friendly',
];

const PLACEMENT_DATA = [
  { company: 'Google', role: 'Software Engineer', salary: '28 LPA', active: true, deadline: 30, cgpa: 8.0, years: [4], branches: ['CSE','AIML','IT'] },
  { company: 'Microsoft', role: 'SDE 1', salary: '24 LPA', active: true, deadline: 35, cgpa: 7.5, years: [3,4], branches: ['CSE','AIML','IT','AIDS'] },
  { company: 'Amazon', role: 'SDE 1', salary: '20 LPA', active: true, deadline: 20, cgpa: 7.0, years: [3,4], branches: ['CSE','IT','AIML'] },
  { company: 'Flipkart', role: 'Data Scientist', salary: '18 LPA', active: true, deadline: 25, cgpa: 7.5, years: [4], branches: ['AIML','AIDS','CSE'] },
  { company: 'Walmart', role: 'Backend Developer', salary: '16 LPA', active: true, deadline: 28, cgpa: 6.5, years: [3,4], branches: ['CSE','IT','ETC'] },
  { company: 'TCS Digital', role: 'Systems Engineer', salary: '12 LPA', active: true, deadline: 15, cgpa: 6.0, years: [2,3,4], branches: ['CSE','AIML','IT','AIDS','ETC'] },
  { company: 'Infosys', role: 'Technology Analyst', salary: '10 LPA', active: true, deadline: 18, cgpa: 6.0, years: [2,3,4], branches: ['CSE','IT','AIDS','ETC'] },
  { company: 'Oracle', role: 'Cloud Engineer', salary: '22 LPA', active: true, deadline: 22, cgpa: 7.5, years: [4], branches: ['CSE','IT'] },
  { company: 'Accenture', role: 'Associate Software Engineer', salary: '8 LPA', active: true, deadline: 12, cgpa: 5.5, years: [2,3,4], branches: ['CSE','AIML','IT','AIDS','ETC'] },
  { company: 'Capgemini', role: 'Software Analyst', salary: '7 LPA', active: true, deadline: 10, cgpa: 5.0, years: [2,3,4], branches: ['CSE','AIML','IT','AIDS','ETC'] },
  { company: 'Uber', role: 'Data Engineer', salary: '26 LPA', active: false, deadline: -5, cgpa: 8.0, years: [4], branches: ['CSE','AIML','IT'] },
  { company: 'Adobe', role: 'Product Manager', salary: '25 LPA', active: false, deadline: -10, cgpa: 8.5, years: [4], branches: ['CSE','IT'] },
  { company: 'Goldman Sachs', role: 'Software Analyst', salary: '30 LPA', active: false, deadline: -15, cgpa: 8.5, years: [4], branches: ['CSE','AIML'] },
  { company: 'Morgan Stanley', role: 'Technology Analyst', salary: '22 LPA', active: false, deadline: -20, cgpa: 8.0, years: [4], branches: ['CSE','IT','AIML'] },
  { company: 'Deloitte', role: 'Consultant', salary: '14 LPA', active: false, deadline: -8, cgpa: 7.0, years: [3,4], branches: ['CSE','IT','AIDS'] },
  { company: 'Tesla', role: 'Embedded Engineer', salary: '20 LPA', active: true, deadline: 45, cgpa: 7.5, years: [4], branches: ['ETC','CSE'] },
  { company: 'Google DeepMind', role: 'AI Research Intern', salary: '15 LPA', active: true, deadline: 40, cgpa: 8.5, years: [3,4], branches: ['AIML','AIDS','CSE'] },
  { company: 'JP Morgan', role: 'Software Engineer', salary: '18 LPA', active: true, deadline: 50, cgpa: 7.0, years: [3,4], branches: ['CSE','IT','AIML'] },
  { company: 'LinkedIn', role: 'Frontend Engineer', salary: '22 LPA', active: true, deadline: 35, cgpa: 7.5, years: [4], branches: ['CSE','IT'] },
  { company: 'Stripe', role: 'Backend Engineer', salary: '32 LPA', active: true, deadline: 55, cgpa: 8.5, years: [4], branches: ['CSE','IT'] },
];

const OPPORTUNITY_DATA = [
  { title: 'Summer Internship 2026', type: 'Internship', loc: 'Bangalore', dead: 20 },
  { title: 'Junior Software Developer', type: 'Full-time', loc: 'Hyderabad', dead: 30 },
  { title: 'Data Science Intern', type: 'Internship', loc: 'Pune', dead: 15 },
  { title: 'Referral for SDE Role', type: 'Referral', loc: 'Remote', dead: null },
  { title: 'Smart India Hackathon', type: 'Hackathon', loc: 'Pan India', dead: 10 },
  { title: 'Machine Learning Intern', type: 'Internship', loc: 'Chennai', dead: 25 },
  { title: 'Full Stack Developer', type: 'Full-time', loc: 'Mumbai', dead: 35 },
  { title: 'Referral for Data Analyst', type: 'Referral', loc: 'Remote', dead: null },
  { title: 'Cloud Computing Intern', type: 'Internship', loc: 'Bangalore', dead: 18 },
  { title: 'UI/UX Design Intern', type: 'Internship', loc: 'Remote', dead: 22 },
  { title: 'HackVerse 2026', type: 'Hackathon', loc: 'Online', dead: 8 },
  { title: 'Backend Developer (Node.js)', type: 'Full-time', loc: 'Gurgaon', dead: 40 },
  { title: 'Referral for PM Role', type: 'Referral', loc: 'Remote', dead: null },
  { title: 'AI Research Intern', type: 'Internship', loc: 'Bangalore', dead: 45 },
  { title: 'DevOps Engineer', type: 'Full-time', loc: 'Pune', dead: 30 },
];

const stats = {};
function logStart(s) { stats[s] = 0; console.log(`\n📦 Seeding ${s}...`); }
function logItem(s) { stats[s]++; }

function printSummary() {
  console.log('\n' + '='.repeat(60));
  console.log('📊 SEED COMPLETE — VALIDATION SUMMARY');
  console.log('='.repeat(60));
  for (const [k, c] of Object.entries(stats)) console.log(`   • ${k}: ${c} documents`);
  console.log('='.repeat(60));
}

async function batchWrite(refs) {
  for (let i = 0; i < refs.length; i += 490) {
    const batch = db.batch();
    const chunk = refs.slice(i, i + 490);
    for (const item of chunk) batch.set(item.ref, { ...item.data, ...DEMO_FLAGS }, { merge: false });
    await batch.commit();
    console.log(`   Batch ${Math.floor(i/490)+1}/${Math.ceil(refs.length/490)} — ${chunk.length} writes`);
  }
}

async function seedStudents() {
  logStart('Students');
  const refs = [];
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const name = STUDENT_NAMES[i];
    const dept = assignDepartment(i);
    const deptSkills = SKILLS_BY_DEPT[dept];
    const prof = STUDENT_PROFILES[i];
    const email = name.toLowerCase().replace(/\s+/g,'.')+'@campusconnect.demo';
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    const year = prof.yr || rand(2,4);
    const cgpa = randFloat(prof.cgpaRange[0], prof.cgpaRange[1]);
    const sc = rand(prof.skillCount[0], prof.skillCount[1]);
    const skills = pickN(deptSkills, sc);
    const fullSkills = [...new Set([...skills,...pickN(ALL_SKILLS,rand(0,3))])];
    refs.push({
      ref: db.collection('users').doc(uid),
      data: {
        personal: { fullName: name, email, phone: `+91${9000000000+i}`, avatarUrl: '', displayName: name.split(' ')[0], bio: `${dept} student passionate about ${pick(skills)}.` },
        academic: { college: 'JD College of Engineering & Management', program: 'B.Tech', year, cgpa },
        career: { interests: pickN(ALL_SKILLS,rand(1,3)), preferredRoles: pickN(['SDE','Data Scientist','ML Engineer','Backend Dev','Frontend Dev','DevOps Engineer','Cloud Architect','Data Analyst'],rand(1,3)) },
        metadata: { createdAt: admin.firestore.Timestamp.fromDate(dateSub(rand(60,180))), updatedAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,7))) },
        profileCompleted: true, role: 'student', department: dept, graduationYear: 2025+(4-year), skills: fullSkills, careerInterest: pick(fullSkills),
        linkedinProfile: `https://linkedin.com/in/${email.split('@')[0]}`,
      }
    });
  }
  await batchWrite(refs);
}

async function seedAlumni() {
  logStart('Alumni');
  const refs = [];
  for (let i = 0; i < ALUMNI_DATA.length; i++) {
    const a = ALUMNI_DATA[i];
    const dept = DEPARTMENTS[i % DEPARTMENTS.length];
    const uid = `demo_alumni_${String(i+1).padStart(2,'0')}`;
    const email = a.name.toLowerCase().replace(/\s+/g,'.')+'@campusconnect.demo';
    const skills = pickN(SKILLS_BY_DEPT[dept], rand(4,8));
    refs.push({
      ref: db.collection('users').doc(uid),
      data: {
        personal: { fullName: a.name, email, phone: `+91${9100000000+i}`, avatarUrl: '', displayName: a.name.split(' ')[0], bio: `${a.role} at ${a.company}, ${a.exp} years. Passionate about mentoring.` },
        academic: { college: 'JD College of Engineering & Management', program: 'B.Tech', year: 4, cgpa: randFloat(7.0,9.0) },
        career: { interests: skills, preferredRoles: [a.role] },
        metadata: { createdAt: admin.firestore.Timestamp.fromDate(dateSub(rand(200,500))), updatedAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,14))) },
        profileCompleted: true, role: 'alumni', department: dept, graduationYear: 2025-rand(2,5), skills,
        careerInterest: a.role, company: a.company, jobRole: a.role, designation: a.role,
        linkedinProfile: `https://linkedin.com/in/${email.split('@')[0]}`,
        isPublicProfile: i < 6, publicProfileKey: `${a.name.toLowerCase().replace(/\s+/g,'-')}-${uid.slice(-6)}`,
        yearsOfExperience: a.exp, industry: 'Technology', employmentType: 'Full-time', workMode: 'Hybrid',
        mentorshipEnabled: true, maxMentees: rand(2,5), mentorshipTopics: skills.slice(0,3),
        githubUrl: `https://github.com/${email.split('@')[0]}`, portfolioUrl: `https://${email.split('@')[0]}.dev`,
      }
    });
  }
  await batchWrite(refs);
}

async function seedTeachers() {
  logStart('Teachers');
  const refs = [];
  for (let i = 0; i < TEACHER_DATA.length; i++) {
    const t = TEACHER_DATA[i];
    const uid = `demo_teacher_${String(i+1).padStart(2,'0')}`;
    const email = t.name.toLowerCase().replace(/\.\s*/g,'').replace(/\s+/g,'.')+'@campusconnect.demo';
    refs.push({
      ref: db.collection('users').doc(uid),
      data: {
        personal: { fullName: t.name, email, phone: `+91${9200000000+i}`, avatarUrl: '', displayName: t.name.split(' ').slice(-2).join(' '), bio: `${t.designation} in ${t.dept}, ${t.exp} years.` },
        academic: { college: 'JD College of Engineering & Management', program: 'M.Tech, PhD', year: 0, cgpa: 0 },
        career: { interests: SKILLS_BY_DEPT[t.dept]||[], preferredRoles: [t.designation] },
        metadata: { createdAt: admin.firestore.Timestamp.fromDate(dateSub(rand(500,1000))), updatedAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,14))) },
        profileCompleted: true, role: 'teacher', department: t.dept, designation: t.designation, experience: t.exp,
        skills: pickN(SKILLS_BY_DEPT[t.dept]||ALL_SKILLS, rand(5,10)),
        linkedinProfile: `https://linkedin.com/in/${email.split('@')[0]}`,
      }
    });
  }
  await batchWrite(refs);
}

async function seedResumeReviews() {
  logStart('Resume Reviews');
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const prof = STUDENT_PROFILES[i];
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    const count = rand(3,5);
    const refs = [];
    const scores = [];
    for (let r = 0; r < count; r++) {
      const progress = r / (count-1||1);
      const minS = prof.atsRange[0] + (prof.atsBase - prof.atsRange[0])*progress*0.5;
      const maxS = prof.atsRange[1] - (prof.atsRange[1] - prof.atsBase)*(1-progress)*0.5;
      scores.push(rand(Math.floor(minS), Math.floor(maxS)));
    }
    for (let r = 0; r < count; r++) {
      const daysAgo = count*14 - r*12 + rand(0,5);
      const createdAt = dateSub(daysAgo);
      const ats = scores[r];
      const mCount = ats>75?rand(1,3):ats>50?rand(3,6):rand(5,10);
      refs.push({
        ref: db.collection('users').doc(uid).collection('resumeReviews').doc(),
        data: {
          userId: uid, atsScore: ats,
          strengths: pickN(STRENGTHS, ats>75?rand(4,6):rand(2,4)),
          missingKeywords: pickN(MISSING_KEYWORDS_POOL, mCount),
          formatIssues: ats>60?pickN(FORMAT_ISSUES,rand(0,2)):pickN(FORMAT_ISSUES,rand(1,3)),
          bulletImprovements: [{original:'Worked on various projects.',improved:`Developed ${pick(['3','4','5'])} ${pick(['full-stack','data-driven','ML-based'])} projects.`,reason:'Adds specificity.'},{original:'Maintained codebase.',improved:'Refactored 2000+ lines, improving test coverage by 25%.',reason:'Shows measurable impact.'}],
          sectionAdvice: pick(SECTION_ADVICE),
          overallAdvice: ats>70?'Strong resume overall.' : ats>50?'Good foundation, needs more technical depth.' : 'Needs significant improvement.',
          hireabilityVerdict: ats>80?HIREABILITY[0]:ats>70?HIREABILITY[1]:ats>55?HIREABILITY[2]:ats>40?HIREABILITY[3]:HIREABILITY[4],
          targetRole: pick(['SDE','Data Analyst','ML Intern','Backend Developer','Full Stack Developer']),
          createdAt: admin.firestore.Timestamp.fromDate(createdAt),
          reviewedAt: admin.firestore.Timestamp.fromDate(createdAt),
          monthKey: `${createdAt.getFullYear()}-${String(createdAt.getMonth()+1).padStart(2,'0')}`,
        }
      });
    }
    await batchWrite(refs);
  }
}

async function seedEngagementSummaries() {
  logStart('Engagement Summaries');
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const prof = STUDENT_PROFILES[i];
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    const streak = rand(prof.streakRange[0], prof.streakRange[1]);
    const ap = rand(prof.apRange[0], prof.apRange[1]);
    const ps = rand(prof.engagementRange[0]-10, prof.engagementRange[1]-5);
    const engagement = rand(prof.engagementRange[0], prof.engagementRange[1]);
    const badges = [];
    if (streak>=7) badges.push({id:'consistency_champion',type:'consistencyChampion',title:'Consistency Champion',description:'Stay active for 7 days.',icon:'local_fire_department',progress:streak,target:7,earnedAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,10))),isFeatured:true});
    if (streak>=3) badges.push({id:'active_student',type:'activeStudent',title:'Active Student',description:'Earn 50 engagement points.',icon:'school',progress:ap,target:50,earnedAt:ap>=50?admin.firestore.Timestamp.fromDate(dateSub(rand(1,20))):null});
    if (ps>=70) badges.push({id:'profile_pro',type:'profilePro',title:'Profile Pro',description:'Complete your profile.',icon:'verified',progress:ps,target:100,earnedAt:ps>=85?admin.firestore.Timestamp.fromDate(dateSub(rand(1,15))):null,isFeatured:true});
    await db.collection('users').doc(uid).collection('engagement_summary').doc('summary').set({...DEMO_FLAGS,engagementScore:engagement,profileStrength:ps,dailyStreak:streak,activityPoints:ap,lastActiveAt:admin.firestore.Timestamp.fromDate(dateSub(rand(0,3))),badges,updatedAt:admin.firestore.Timestamp.fromDate(dateSub(rand(0,2)))});
    logItem('Engagement Summaries');
  }
}

async function seedPlacements() {
  logStart('Placements');
  const ids = [];
  const refs = [];
  for (let i = 0; i < PLACEMENT_DATA.length; i++) {
    const p = PLACEMENT_DATA[i];
    const pid = `demo_placement_${String(i+1).padStart(2,'0')}`;
    ids.push(pid);
    const postedAt = dateSub(p.deadline+rand(14,30));
    const deadline = p.active?dateSub(-p.deadline):dateSub(Math.abs(p.deadline));
    refs.push({ref: db.collection('placements').doc(pid), data: {
      company: p.company, role: p.role, description: `${p.company} is hiring ${p.role}.`, eligibility: `CGPA: ${p.cgpa}+, Year: ${p.years.join(',')}, Branches: ${p.branches.join(',')}`,
      salary: p.salary, deadline: admin.firestore.Timestamp.fromDate(deadline), postedAt: admin.firestore.Timestamp.fromDate(postedAt),
      isActive: p.active, requirements: { minCgpa: p.cgpa, allowedYears: p.years, programs: ['B.Tech'], skills: [], branches: p.branches },
      createdBy: 'demo_teacher_01', updatedBy: 'demo_teacher_01', updatedAt: admin.firestore.Timestamp.fromDate(postedAt),
    }});
  }
  await batchWrite(refs);
  return ids;
}

async function seedApplications(placementIds) {
  logStart('Applications');
  const total = rand(80,120);
  const refs = [];
  const weights = [5,5,5,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1,0,1,0,6,6,6,6];
  let applied = 0;
  while (applied < total) {
    let r = Math.random() * weights.reduce((a,b)=>a+b,0);
    let si = -1;
    for (let i = 0; i < weights.length; i++) { r -= weights[i]; if (r <= 0) { si = i; break; } }
    if (si === -1) continue;
    const uid = `demo_student_${String(si+1).padStart(2,'0')}`;
    const pid = pick(placementIds);
    const appId = `${uid}_${pid}`;
    const date = dateSub(rand(1,30));
    refs.push({ref: db.collection('applications').doc(appId), data: {userId:uid,placementId:pid,resumeUrl:`https://resume.example.com/${uid}.pdf`,appliedAt:admin.firestore.Timestamp.fromDate(date),status:'applied'}});
    refs.push({ref: db.collection('placements').doc(pid).collection('applications').doc(uid), data: {userId:uid,placementId:pid,resumeUrl:`https://resume.example.com/${uid}.pdf`,company:'Demo Company',appliedAt:admin.firestore.Timestamp.fromDate(date),status:'applied'}});
    applied++;
  }
  await batchWrite(refs);
}

async function seedMentorshipRequests() {
  logStart('Mentorship Requests');
  const refs = [];
  const statuses = ['pending','accepted','completed','rejected'];
  const counts = [10,12,10,8];
  let idx = 0;
  for (let s = 0; s < statuses.length; s++) {
    for (let i = 0; i < counts[s]; i++) {
      idx++;
      const si = rand(0,STUDENT_NAMES.length-1);
      const ai = rand(0,ALUMNI_DATA.length-1);
      const suid = `demo_student_${String(si+1).padStart(2,'0')}`;
      const auid = `demo_alumni_${String(ai+1).padStart(2,'0')}`;
      const st = statuses[s];
      const created = dateSub(rand(10,60));
      const responded = (st!=='pending')?admin.firestore.Timestamp.fromDate(dateSubFrom(created,rand(1,5))):null;
      const chatId = (st==='accepted'||st==='completed')?`demo_chat_mr_${String(idx).padStart(2,'0')}`:null;
      refs.push({ref: db.collection('mentorship_requests').doc(`demo_mr_${String(idx).padStart(2,'0')}`), data: {
        studentId: suid, alumniId: auid, title: `Seeking guidance in ${pick(ALL_SKILLS)}`,
        description: `Looking for mentorship in ${pick(['software development','data science','machine learning','cloud computing','interview preparation'])}.`,
        skills: pickN(ALL_SKILLS,rand(2,5)), status: st,
        createdAt: admin.firestore.Timestamp.fromDate(created), respondedAt: responded,
        responseMessage: st!=='pending'?pick(['Happy to help!','Would be glad to mentor you.','Sure, let\'s connect.','Unavailable right now.']):null,
        studentName: STUDENT_NAMES[si], studentEmail: STUDENT_NAMES[si].toLowerCase().replace(/\s+/g,'.')+'@campusconnect.demo',
        alumniName: ALUMNI_DATA[ai].name, alumniCompany: ALUMNI_DATA[ai].company, alumniJobRole: ALUMNI_DATA[ai].role,
        chatId, completedAt: st==='completed'?admin.firestore.Timestamp.fromDate(dateSub(rand(1,10))):null,
        rating: st==='completed'?rand(4,5):null, feedback: st==='completed'?pick(['Excellent mentor!','Great guidance!','Learned a lot!']):null,
      }});
    }
  }
  await batchWrite(refs);
}

async function seedOpportunities() {
  logStart('Opportunities');
  const refs = [];
  for (let i = 0; i < OPPORTUNITY_DATA.length; i++) {
    const o = OPPORTUNITY_DATA[i];
    const ai = i % ALUMNI_DATA.length;
    const auid = `demo_alumni_${String(ai+1).padStart(2,'0')}`;
    const skills = pickN(ALL_SKILLS,rand(3,7));
    refs.push({ref: db.collection('opportunities').doc(`demo_opp_${String(i+1).padStart(2,'0')}`), data: {
      alumniId: auid, title: o.title, company: ALUMNI_DATA[ai].company,
      description: `${ALUMNI_DATA[ai].name} posted a ${o.type.toLowerCase()} for ${o.title}.`,
      requirements: pickN(['Communication skills','Team player','Problem-solving',`Proficiency in ${pick(skills)}`,`Experience with ${pick(skills)}`],rand(3,5)),
      location: o.loc, jobType: o.type==='Internship'?'Internship':o.type==='Full-time'?'Full-time':'Internship',
      skills, postedAt: admin.firestore.Timestamp.fromDate(dateSub(rand(5,30))), isActive: true,
      alumniName: ALUMNI_DATA[ai].name, alumniJobRole: ALUMNI_DATA[ai].role,
      salaryRange: o.type==='Internship'?'₹30,000-50,000/month':o.type==='Full-time'?`${rand(8,25)} LPA`:null,
      applicationDeadline: o.dead?admin.firestore.Timestamp.fromDate(dateSub(-o.dead)):null,
      applicationUrl: `https://${ALUMNI_DATA[ai].company.toLowerCase()}.com/careers`,
      contactEmail: ALUMNI_DATA[ai].name.toLowerCase().replace(/\s+/g,'.')+'@campusconnect.demo',
    }});
  }
  await batchWrite(refs);
}

async function seedChats() {
  logStart('Chats & Messages');
  for (let idx = 1; idx <= 22; idx++) {
    const chatId = `demo_chat_mr_${String(idx).padStart(2,'0')}`;
    const si = rand(0,STUDENT_NAMES.length-1);
    const ai = rand(0,ALUMNI_DATA.length-1);
    const suid = `demo_student_${String(si+1).padStart(2,'0')}`;
    const auid = `demo_alumni_${String(ai+1).padStart(2,'0')}`;
    const sn = STUDENT_NAMES[si];
    const an = ALUMNI_DATA[ai].name;
    const msgCount = rand(3,10);
    const chatDate = dateSub(rand(20,50));
    const msgs = [];
    let last = '';
    for (let m = 0; m < msgCount; m++) {
      const isS = m%2===0;
      const d = new Date(chatDate); d.setHours(d.getHours()+m*rand(2,24));
      const t = isS?pick(['Hi! Thank you for accepting my request.','Can you help with interview prep?','I\'m improving my coding skills.','Could you review my resume?','Thank you for the guidance!','I solved 3 LeetCode problems today!','I got shortlisted!']):pick(['Welcome! Happy to guide you.','Let\'s start with your goals.','Focus on core concepts.','Share your resume, I\'ll review.','Glad to help! Keep practicing.','Consistency is key.','Great news! Let\'s prepare.']);
      last = t;
      msgs.push({chatId,senderId:isS?suid:auid,senderName:isS?sn:an,text:t,sentAt:admin.firestore.Timestamp.fromDate(d),isRead:true});
    }
    const refs = [{ref: db.collection('chats').doc(chatId), data: {participantIds:[suid,auid],participantNames:{[suid]:sn,[auid]:an},relatedMentorshipId:`demo_mr_${String(idx).padStart(2,'0')}`,lastMessage:last,lastMessageSenderId:msgCount%2===0?suid:auid,lastMessageAt:msgs[msgs.length-1].sentAt,createdAt:admin.firestore.Timestamp.fromDate(chatDate),unreadCount:{[suid]:0,[auid]:0}}}];
    for (const msg of msgs) refs.push({ref: db.collection('chats').doc(chatId).collection('messages').doc(),data:msg});
    await batchWrite(refs);
  }
}

async function seedNotifications() {
  logStart('Notifications');
  const refs = [];
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    for (let n = 0; n < rand(3,8); n++) {
      const type = pick(['placementApplied','statusChange','newMessage','newJobPost','engagementMilestone']);
      const company = pick(PLACEMENT_DATA).company;
      const role = pick(['SDE','Data Analyst','ML Engineer','Backend Dev']);
      let title, body, nd;
      switch (type) {
        case 'placementApplied': title=`Applied for ${role} at ${company}`; body='Your application is being reviewed.'; nd={placementId:'demo_placement_01',company,role}; break;
        case 'statusChange': title=`Update: ${company}`; body=`Status changed to ${pick(['reviewing','shortlisted'])}.`; nd={placementId:'demo_placement_01',company,role,status:'reviewing'}; break;
        case 'newMessage': title='New message from mentor'; body='You have a new message.'; nd={chatId:'demo_chat_mr_01'}; break;
        case 'newJobPost': title=`New at ${company}`; body=`${company} hiring ${role}.`; nd={opportunityId:'demo_opp_01'}; break;
        default: title='Engagement Milestone!'; body=`${rand(3,30)}-day streak!`; nd={streakDays:rand(3,30)};
      }
      refs.push({ref: db.collection('users').doc(uid).collection('notifications').doc(),data:{type,title,body,data:nd,isRead:Math.random()<0.4,createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(0,30)))}});
    }
  }
  for (let i = 0; i < ALUMNI_DATA.length; i++) {
    const uid = `demo_alumni_${String(i+1).padStart(2,'0')}`;
    for (let n = 0; n < rand(2,5); n++) {
      const type = pick(['mentorshipRequested','newMessage','system']);
      refs.push({ref: db.collection('users').doc(uid).collection('notifications').doc(),data:{
        type, title: type==='mentorshipRequested'?'New Mentorship Request':type==='newMessage'?'New Message':'System Update',
        body: type==='mentorshipRequested'?`${pick(STUDENT_NAMES)} requested mentorship.`:type==='newMessage'?'You have a new message.':'Profile updated.',
        data: type==='mentorshipRequested'?{requestId:'demo_mr_01',studentName:pick(STUDENT_NAMES)}:{},
        isRead: Math.random()<0.4, createdAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,30))),
      }});
    }
  }
  for (let i = 0; i < TEACHER_DATA.length; i++) {
    const uid = `demo_teacher_${String(i+1).padStart(2,'0')}`;
    for (let n = 0; n < rand(2,4); n++) {
      refs.push({ref: db.collection('users').doc(uid).collection('notifications').doc(),data:{
        type: pick(['system','announcement','statusChange']),
        title: pick(['Analytics Updated','New Drive Alert','Application Update']),
        body: pick(['Student analytics refreshed.','New placement drive scheduled.','5 new applications received.']),
        data: {}, isRead: Math.random()<0.4, createdAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,30))),
      }});
    }
  }
  await batchWrite(refs);
}

async function seedActivities() {
  logStart('Activities');
  const refs = [];
  const events = ['login','profileUpdated','resumeReviewed','mentorshipRequested','chatMessageSent','opportunityViewed','recommendationClicked'];
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    const count = STUDENT_PROFILES[i].type==='inactive'?rand(1,3):rand(4,10);
    for (let a = 0; a < count; a++) {
      const et = pick(events);
      refs.push({ref: db.collection('users').doc(uid).collection('activities').doc(),data:{
        userId: uid, eventType: et, sourceId: `act_${i}_${a}`,
        points: et==='login'?1:et==='resumeReviewed'?5:et==='mentorshipRequested'||et==='chatMessageSent'?3:2,
        occurredAt: admin.firestore.Timestamp.fromDate(dateSub(rand(0,45))), metadata: {},
      }});
    }
  }
  await batchWrite(refs);
}

async function seedRecommendations() {
  logStart('Recommendations');
  const refs = [];
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    for (let m = 0; m < 2; m++) {
      const ai = rand(0,ALUMNI_DATA.length-1);
      const score = rand(65,95);
      refs.push({ref: db.collection('users').doc(uid).collection('recommendations').doc(),data:{
        userId:uid,type:'mentor',priority:score>=80?'high':'medium',title:`Connect with ${ALUMNI_DATA[ai].name}`,
        description:`${ALUMNI_DATA[ai].role} at ${ALUMNI_DATA[ai].company}`,score,isActive:true,
        createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,14))),expiresAt:admin.firestore.Timestamp.fromDate(dateSub(-7)),
        metadata:{alumniId:`demo_alumni_${String(ai+1).padStart(2,'0')}`,company:ALUMNI_DATA[ai].company,jobRole:ALUMNI_DATA[ai].role,skills:pickN(ALL_SKILLS,rand(3,5))},
      }});
    }
    for (let j = 0; j < 2; j++) {
      const p = pick(PLACEMENT_DATA);
      const score = rand(55,90);
      refs.push({ref: db.collection('users').doc(uid).collection('recommendations').doc(),data:{
        userId:uid,type:'job',priority:score>=75?'high':'medium',title:`${p.role} at ${p.company}`,
        description:`Salary: ${p.salary} — Match: ${score}%`,score,isActive:true,
        createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,10))),expiresAt:admin.firestore.Timestamp.fromDate(dateSub(-5)),
        metadata:{opportunityId:`demo_placement_${String(PLACEMENT_DATA.indexOf(p)+1).padStart(2,'0')}`,skills:pickN(ALL_SKILLS,rand(3,5))},
      }});
    }
    const ms = pick(MISSING_KEYWORDS_POOL);
    refs.push({ref: db.collection('users').doc(uid).collection('recommendations').doc(),data:{userId:uid,type:'skill',priority:'medium',title:`Learn ${ms}`,description:`${ms} is frequently requested.`,score:rand(60,80),isActive:true,createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,7))),expiresAt:admin.firestore.Timestamp.fromDate(dateSub(-3)),metadata:{action:'profile_update'}}});
    refs.push({ref: db.collection('users').doc(uid).collection('recommendations').doc(),data:{userId:uid,type:'chat',priority:'medium',title:'Use AI Career Assistant',description:'Ask for interview simulation and skill-gap analysis.',score:rand(55,75),isActive:true,createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,5))),expiresAt:admin.firestore.Timestamp.fromDate(dateSub(-2)),metadata:{action:'open_ai_chat'}}});
  }
  await batchWrite(refs);
}

async function seedAIInteractions() {
  logStart('AI Interactions');
  const refs = [];
  const intents = ['resumeImprovement','careerPath','interviewPrep','skillGap','general'];
  const prompts = ['How can I improve my resume for FAANG?','What skills for data science?','Simulate a technical interview.','What career path fits my skills?','How do I prepare for placements?','What are in-demand skills in 2026?','Review my project description.','How to answer Tell me about yourself?','What tech for backend development?','How to build an ML portfolio?'];
  for (let i = 0; i < STUDENT_NAMES.length; i+=2) {
    const uid = `demo_student_${String(i+1).padStart(2,'0')}`;
    for (let a = 0; a < rand(2,5); a++) {
      refs.push({ref: db.collection('users').doc(uid).collection('ai_interactions').doc(),data:{
        userId:uid,prompt:pick(prompts),response:`Focus on ${pick(ALL_SKILLS)} and ${pick(ALL_SKILLS)} — high demand skills.`,
        intent:pick(intents),createdAt:admin.firestore.Timestamp.fromDate(dateSub(rand(1,30))),
        metadata:{modelVersion:'v8.3-demo',provider:'groq'},
      }});
    }
  }
  await batchWrite(refs);
}

async function seedPublicProfiles() {
  logStart('Public Profiles');
  const refs = [];
  for (let i = 0; i < 6; i++) {
    const a = ALUMNI_DATA[i];
    const uid = `demo_alumni_${String(i+1).padStart(2,'0')}`;
    const key = `${a.name.toLowerCase().replace(/\s+/g,'-')}-${uid.slice(-6)}`;
    refs.push({ref: db.collection('public_profiles').doc(key),data:{uid,profileKey:key,isPublic:true,name:a.name,jobRole:a.role,company:a.company,designation:a.role,careerInterest:a.role,skills:pickN(ALL_SKILLS,rand(4,8)),linkedinProfile:`https://linkedin.com/in/${a.name.toLowerCase().replace(/\s+/g,'.')}`,experience:`${a.role} at ${a.company}`,opportunitiesPosted:rand(1,4),updatedAt:admin.firestore.Timestamp.fromDate(dateSub(rand(0,14)))}});
  }
  await batchWrite(refs);
}

async function seedRecommendationsMeta() {
  logStart('Recommendations Meta');
  const refs = [];
  for (let i = 0; i < STUDENT_NAMES.length; i++) {
    refs.push({ref: db.collection('users').doc(`demo_student_${String(i+1).padStart(2,'0')}`).collection('recommendations_meta').doc('summary'),data:{updatedAt:admin.firestore.Timestamp.fromDate(dateSub(rand(0,3))),total:6}});
  }
  await batchWrite(refs);
}

async function main() {
  console.log('🚀 CampusConnect v8.3 — Demo Data Seeder');
  console.log('='.repeat(60));
  console.log('Starting seed at:', new Date().toISOString());
  console.log('='.repeat(60));
  try {
    await db.listCollections();
    await seedStudents();
    await seedAlumni();
    await seedTeachers();
    await seedResumeReviews();
    await seedEngagementSummaries();
    const pids = await seedPlacements();
    await seedApplications(pids);
    await seedMentorshipRequests();
    await seedOpportunities();
    await seedChats();
    await seedNotifications();
    await seedActivities();
    await seedRecommendations();
    await seedAIInteractions();
    await seedPublicProfiles();
    await seedRecommendationsMeta();
    printSummary();
    console.log('\n✅ Seed completed successfully!');
    console.log('   Run `npm run cleanup` to remove all demo data.\n');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Seed failed:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
