const loginRoute = '/login/';
const registerRoute = '/register/';
const notesRoute = '/notes/';
const verifyEmailRoute = '/verify-email/';
const profileRoute = '/profile/';
const editProfileRoute = '/edit-profile';
const profileSetupRoute = '/profile-setup';
const notificationsRoute = '/notifications';
const settingsRoute = '/settings'; // v6.6
const resumeReviewRoute = '/resume-review'; // v6.7
const resumeReviewHistoryRoute = '/resume-review/history'; // v6.8
const resumeReviewDetailRoute = '/resume-review/detail'; // v6.8
const resumeInsightsRoute = '/resume-review/insights'; // v6.9

// v7.3: Feature-specific routes (extracted from NotesView monolith)
const notesListRoute = '/notes-list';
const uploadNotesRoute = '/upload-notes';
const placementsListRoute = '/placements-list';
const placementApplicantsRoute = '/placements/applicants'; // v9.1
const aiChatRoute = '/ai-chat';

// v7.1: Role-based dashboard routes
const studentDashboardRoute = '/student-dashboard';
const alumniDashboardRoute = '/alumni-dashboard';
const teacherDashboardRoute = '/teacher-dashboard';

// v7.2: Multi-role ecosystem routes
const alumniDirectoryRoute = '/alumni-directory';
const alumniProfileRoute = '/alumni-profile';
const mentorshipRequestsRoute = '/mentorship-requests';
const createMentorshipRequestRoute = '/create-mentorship-request';
const mentorshipRequestDetailRoute = '/mentorship-request-detail';
const completeMentorshipRoute = '/complete-mentorship'; // v7.3
const opportunitiesRoute = '/opportunities';
const createOpportunityRoute = '/create-opportunity';
const opportunityDetailRoute = '/opportunity-detail';
const studentAnalyticsRoute = '/student-analytics';

// v7.5: Teacher notes management route
const teacherNotesRoute = '/teacher-notes';

// v7.6: Password reset route
const passwordResetRoute = '/password-reset';

// v7.3: Chat routes
const chatsListRoute = '/chats';
const chatRoute = '/chat';
const chatDetailRoute = '/chat-detail';

// v9.0: AI Career Coach — full analysis screen (dashboard shows top 2–3)
const careerCoachRoute = '/career-coach';

// v8.4: Student Resume Portfolio routes
const studentPortfolioRoute = '/student-portfolio';
const editPortfolioRoute = '/edit-portfolio';
const projectsManagerRoute = '/portfolio/projects';
const certificationsManagerRoute = '/portfolio/certifications';
const experienceManagerRoute = '/portfolio/experience';
const achievementsManagerRoute = '/portfolio/achievements';
const resumeUploadRoute = '/portfolio/resume-upload';
const portfolioReadOnlyRoute = '/portfolio/readonly';

// v8.7: Alumni Group Chat route
const alumniGroupChatRoute = '/alumni-group-chat';
