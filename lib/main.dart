import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/models/mentorship_request.dart'; // v7.3
import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/firebase_options.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/alumni_group_chat_provider.dart'; // v8.7
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/portfolio_provider.dart'; // v8.4
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/theme_provider.dart'; // v7.2: Multi-role ecosystem providers
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart'; // v7.3: Chat provider
import 'package:campusconnect/providers/chat_provider.dart';
import 'package:campusconnect/providers/teacher_analytics_provider.dart'; // v7.3
import 'package:campusconnect/providers/activity_feed_provider.dart'; // v7.3: Activity feed
import 'package:campusconnect/providers/ai_chat_provider.dart'; // v7.4
import 'package:campusconnect/providers/recommendation_provider.dart'; // v7.4
import 'package:campusconnect/providers/engagement_provider.dart'; // v7.4
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/ai/resume_review_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notifications_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/services/firestore/alumni_directory_service.dart';
import 'package:campusconnect/services/firestore/mentorship_service.dart';
import 'package:campusconnect/services/firestore/opportunity_service.dart';
import 'package:campusconnect/services/firestore/recommendation_service.dart'; // v7.4
import 'package:campusconnect/services/firestore/engagement_service.dart'; // v7.4
// v7.3: Chat service
import 'package:campusconnect/services/firestore/chat_service.dart';
import 'package:campusconnect/services/firestore/teacher_analytics_service.dart'; // v7.3
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/dashboards/alumni_dashboard_view.dart';
import 'package:campusconnect/views/dashboards/student_dashboard_view.dart';
import 'package:campusconnect/views/dashboards/teacher_dashboard_view.dart';
import 'package:campusconnect/views/edit_profile_view.dart';
import 'package:campusconnect/views/login_view.dart';
// Legacy import deprecated - NotesView decomposed into focused feature views
// import 'package:campusconnect/views/notes_view.dart';
import 'package:campusconnect/views/notifications_view.dart';
import 'package:campusconnect/views/profile_setup_view.dart';
import 'package:campusconnect/views/register_view.dart';
import 'package:campusconnect/views/resume_review_detail_view.dart'; // v6.8
import 'package:campusconnect/views/resume_review_history_view.dart'; // v6.8
import 'package:campusconnect/views/resume_insights_view.dart'; // v6.9
import 'package:campusconnect/views/resume_review_view.dart';
import 'package:campusconnect/views/settings_view.dart';
import 'package:campusconnect/views/verify_email_view.dart';
// v7.2: Multi-role ecosystem views
import 'package:campusconnect/views/alumni_directory_view.dart';
import 'package:campusconnect/views/alumni_profile_view.dart';
import 'package:campusconnect/views/mentorship/mentorship_requests_view.dart';
import 'package:campusconnect/views/mentorship/create_mentorship_request_view.dart';
import 'package:campusconnect/views/mentorship/mentorship_request_detail_view.dart';
import 'package:campusconnect/views/mentorship/complete_mentorship_view.dart'; // v7.3
import 'package:campusconnect/views/opportunities/opportunities_view.dart';
import 'package:campusconnect/views/opportunities/create_opportunity_view.dart';
import 'package:campusconnect/views/opportunities/opportunity_detail_view.dart';
import 'package:campusconnect/views/teacher/student_analytics_view.dart';
// v7.3: Chat views
import 'package:campusconnect/views/chats/chats_list_view.dart';
import 'package:campusconnect/views/chats/chat_view.dart';
// v8.7: Alumni Group Chat view
import 'package:campusconnect/views/chats/alumni_group_chat_view.dart';
// v7.3: Extracted feature views (Phase 1 NotesView decomposition)
import 'package:campusconnect/views/notes/notes_list_view.dart';
import 'package:campusconnect/views/notes/upload_notes_view.dart';
// v7.5: Teacher notes management view
import 'package:campusconnect/views/notes/teacher_notes_view.dart';
// v7.6: Password reset view
import 'package:campusconnect/views/password_reset_view.dart';
import 'package:campusconnect/views/placements/placements_list_view.dart';
import 'package:campusconnect/views/chat/ai_chat_view.dart';
import 'package:campusconnect/views/profile/profile_view.dart'
    as extracted_profile;
// v8.4: Student resume portfolio views
import 'package:campusconnect/views/portfolio/student_portfolio_screen.dart';
import 'package:campusconnect/views/portfolio/edit_portfolio_screen.dart';
import 'package:campusconnect/views/portfolio/projects_manager_screen.dart';
import 'package:campusconnect/views/portfolio/certifications_manager_screen.dart';
import 'package:campusconnect/views/portfolio/experience_manager_screen.dart';
import 'package:campusconnect/views/portfolio/achievements_manager_screen.dart';
import 'package:campusconnect/views/portfolio/resume_upload_screen.dart';
import 'package:campusconnect/views/portfolio/portfolio_read_only_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // v8.8.2 (C, MEDIUM): removed the blocking `LocalPreferencesService.init()`
  // from the startup path. Theme/Layout providers self-initialize lazily via
  // their own `init()` (which awaits `_prefs.init()` internally), so the
  // first frame renders with defaults instead of stalling the main thread
  // (~171 skipped frames / 1.27s `Davey!` in the pid 24538 log). The prefs
  // resolve a few frames later and the UI converges to the stored theme.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // V5.1.1: Providers at root level - persist across auth changes
    // V6.6: Added ThemeProvider and LayoutProvider for personalization
    // V7.1: Added RoleProvider for role-based routing
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              PlacementsProvider(service: PlacementsService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) => AIUsageProvider(aiService: AIService.instance()),
        ),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        // v8.4: Student resume portfolio provider
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        // V6.4: Notifications provider
        ChangeNotifierProvider(
          create: (_) =>
              NotificationsProvider(service: NotificationsService.instance()),
        ),
        // V6.6: Theme and layout providers for personalization
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => LayoutProvider()..init()),
        // V6.7: Resume review provider
        ChangeNotifierProvider(
          create: (_) =>
              ResumeReviewProvider(service: ResumeReviewService.instance()),
        ),
        // V7.1: Role provider
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        // V7.2: Multi-role ecosystem providers
        ChangeNotifierProvider(
          create: (_) =>
              MentorshipProvider(service: MentorshipService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              OpportunityProvider(service: OpportunityService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) => AlumniDirectoryProvider(
            service: AlumniDirectoryService.instance(),
          ),
        ),
        // v7.3: Chat provider
        ChangeNotifierProvider(
          create: (_) => ChatProvider(service: ChatService.instance()),
        ),
        // v7.3: Teacher analytics provider
        ChangeNotifierProvider(
          create: (_) => TeacherAnalyticsProvider(
            service: TeacherAnalyticsService.instance(),
          ),
        ),
        // v8.7: Alumni Group Chat provider (stream subscription managed
        // internally; initialized for every signed-in user, read only by
        // Alumni per Firestore rules)
        ChangeNotifierProvider(create: (_) => AlumniGroupChatProvider()),
        // v7.4: AI recommendation and engagement providers
        ChangeNotifierProvider(
          create: (_) =>
              RecommendationProvider(service: RecommendationService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              EngagementProvider(service: EngagementService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) => AIChatProvider(aiService: AIService.instance()),
        ),
        // v7.3: Activity feed provider (depends on other providers)
        ChangeNotifierProxyProvider5<
          NotificationsProvider,
          ChatProvider,
          MentorshipProvider,
          PlacementsProvider,
          OpportunityProvider,
          ActivityFeedProvider
        >(
          create: (context) => ActivityFeedProvider(
            notificationsProvider: context.read<NotificationsProvider>(),
            chatProvider: context.read<ChatProvider>(),
            mentorshipProvider: context.read<MentorshipProvider>(),
            placementsProvider: context.read<PlacementsProvider>(),
            opportunityProvider: context.read<OpportunityProvider>(),
          ),
          update:
              (
                context,
                notifications,
                chat,
                mentorship,
                placements,
                opportunities,
                previous,
              ) =>
                  previous ??
                  ActivityFeedProvider(
                    notificationsProvider: notifications,
                    chatProvider: chat,
                    mentorshipProvider: mentorship,
                    placementsProvider: placements,
                    opportunityProvider: opportunities,
                  ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'CampusConnect',
            theme: AppTheme.lightTheme, // v6.0: Professional design system
            darkTheme: AppTheme.darkTheme, // v6.6: Dark theme support
            themeMode: themeProvider.themeMode, // v6.6: User preference
            home: const AuthGuard(),
            onGenerateRoute: (settings) {
              // v6.8: Handle dynamic routes with arguments
              if (settings.name == resumeReviewDetailRoute) {
                final args = settings.arguments;
                final reviewId = args is String ? args : null;
                if (reviewId == null || reviewId.isEmpty) {
                  return MaterialPageRoute(
                    builder: (context) => const ResumeReviewHistoryView(),
                  );
                }
                return MaterialPageRoute(
                  builder: (context) =>
                      ResumeReviewDetailView(reviewId: reviewId),
                );
              }
              // v7.3: Handle chat route with chatId argument
              if (settings.name == chatRoute ||
                  settings.name == chatDetailRoute) {
                final args = settings.arguments;
                final chatId = args is String ? args : null;
                if (chatId == null || chatId.isEmpty) {
                  return MaterialPageRoute(
                    builder: (context) => const ChatsListView(),
                  );
                }
                return MaterialPageRoute(
                  builder: (context) => ChatView(chatId: chatId),
                );
              }
              // v7.3: Handle complete mentorship route with request argument
              if (settings.name == completeMentorshipRoute) {
                final args = settings.arguments;
                if (args is! MentorshipRequest) {
                  return MaterialPageRoute(
                    builder: (context) => const MentorshipRequestsView(),
                  );
                }
                final request = args;
                return MaterialPageRoute(
                  builder: (context) =>
                      CompleteMentorshipView(request: request),
                );
              }
              return null; // Let routes handle it
            },
            routes: {
              loginRoute: (context) => const LoginView(),
              registerRoute: (context) => const RegisterView(),
              // Legacy route deprecated - routes to StudentDashboardView for compatibility
              notesRoute: (context) => const StudentDashboardView(),
              verifyEmailRoute: (context) => const VerifyEmailView(),
              // v8.8.3 (MED-6): `/profile/` now maps to the extracted
              // ProfileView (role-aware alumni/student/teacher layout) — the
              // legacy v2 shim was dead code and `/profile-view` was its
              // duplicate. `profileViewRoute` is removed below; the alumni and
              // teacher dashboards already navigate to `/profile/`.
              profileRoute: (context) => const extracted_profile.ProfileView(),
              editProfileRoute: (context) => const EditProfileView(),
              profileSetupRoute: (context) => const ProfileSetupView(),
              notificationsRoute: (context) => const NotificationsView(),
              settingsRoute: (context) => const SettingsView(), // v6.6
              resumeReviewRoute: (context) => const ResumeReviewView(), // v6.7
              resumeReviewHistoryRoute: (context) =>
                  const ResumeReviewHistoryView(), // v6.8
              resumeInsightsRoute: (context) =>
                  const ResumeInsightsView(), // v6.9
              // v7.1: Role-based dashboard routes
              studentDashboardRoute: (context) => const StudentDashboardView(),
              alumniDashboardRoute: (context) => const AlumniDashboardView(),
              teacherDashboardRoute: (context) => const TeacherDashboardView(),
              // v7.2: Multi-role ecosystem routes
              alumniDirectoryRoute: (context) => const AlumniDirectoryView(),
              alumniProfileRoute: (context) => const AlumniProfileView(),
              mentorshipRequestsRoute: (context) =>
                  const MentorshipRequestsView(),
              createMentorshipRequestRoute: (context) =>
                  const CreateMentorshipRequestView(),
              mentorshipRequestDetailRoute: (context) =>
                  const MentorshipRequestDetailView(),
              opportunitiesRoute: (context) => const OpportunitiesView(),
              createOpportunityRoute: (context) =>
                  const CreateOpportunityView(),
              opportunityDetailRoute: (context) =>
                  const OpportunityDetailView(),
              studentAnalyticsRoute: (context) => const StudentAnalyticsView(),
              // v7.3: Chat routes
              chatsListRoute: (context) => const ChatsListView(),
              // v7.5: Teacher notes management route
              teacherNotesRoute: (context) => const TeacherNotesView(),
              // v7.3: Extracted feature routes (Phase 1 NotesView decomposition)
              notesListRoute: (context) => const NotesListView(),
              uploadNotesRoute: (context) => const UploadNotesView(),
              placementsListRoute: (context) => const PlacementsListView(),
              aiChatRoute: (context) => const AIChatView(),
              // v7.6: Password reset route
              passwordResetRoute: (context) => const PasswordResetView(),
              // v8.4: Student resume portfolio routes
              // v8.7: Editing routes are role-gated — Alumni may not enter the
              // Student Portfolio editing workflow (Task §1/§5/§14). The
              // read-only route stays open so Alumni can still VIEW a
              // student's portfolio (Task §13).
              studentPortfolioRoute: (context) => _guardStudentPortfolio(
                context,
                const StudentPortfolioScreen(),
              ),
              editPortfolioRoute: (context) =>
                  _guardStudentPortfolio(context, const EditPortfolioScreen()),
              projectsManagerRoute: (context) => _guardStudentPortfolio(
                context,
                const ProjectsManagerScreen(),
              ),
              certificationsManagerRoute: (context) => _guardStudentPortfolio(
                context,
                const CertificationsManagerScreen(),
              ),
              experienceManagerRoute: (context) => _guardStudentPortfolio(
                context,
                const ExperienceManagerScreen(),
              ),
              achievementsManagerRoute: (context) => _guardStudentPortfolio(
                context,
                const AchievementsManagerScreen(),
              ),
              resumeUploadRoute: (context) =>
                  _guardStudentPortfolio(context, const ResumeUploadScreen()),
              portfolioReadOnlyRoute: (context) =>
                  const PortfolioReadOnlyView(),
              // v8.7: Alumni Group Chat route — Alumni-only. Non-Alumni
              // (Students/Teachers) get a denied screen instead of the chat;
              // Firestore rules enforce identity + role server-side too.
              alumniGroupChatRoute: (context) =>
                  _guardAlumniGroupChat(context, const AlumniGroupChatView()),
            },
          );
        },
      ),
    );
  }
}

/// v8.7: Role-gates the Student Portfolio editing workflow.
///
/// Portfolio is a Student career-development feature. Alumni may not enter
/// the editable portfolio screens (Task §1/§5/§14) — if an Alumni route is
/// manually accessed, show a safe blocked message instead of the editing UI.
/// Students and Teachers continue to reach the screens unchanged. The
/// read-only student portfolio route (`portfolioReadOnlyRoute`) is NOT gated
/// so Alumni can still view a Student's portfolio (Task §13).
Widget _guardStudentPortfolio(BuildContext context, Widget child) {
  final role = context.watch<RoleProvider>().userRole;
  if (role == UserRole.alumni) {
    return const _StudentPortfolioBlockedView();
  }
  return child;
}

/// v8.7: Role-gates the Alumni Group Chat — Alumni-only (Task §6/§8).
///
/// Students, Teachers and roles not yet resolved are shown a safe blocked
/// message instead of entering the chat. Firestore rules provide the same
/// Alumni-only enforcement server-side (`alumni_group_messages`), so a
/// malicious client bypassing this guard still cannot read or write.
Widget _guardAlumniGroupChat(BuildContext context, Widget child) {
  final role = context.watch<RoleProvider>().userRole;
  if (role != UserRole.alumni) {
    return const _AlumniGroupChatDeniedView();
  }
  return child;
}

/// Denied state for non-Alumni reaching the Alumni Group Chat route.
class _AlumniGroupChatDeniedView extends StatelessWidget {
  const _AlumniGroupChatDeniedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alumni Community'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Alumni Only',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                'The Alumni Community is available to verified Alumni only.',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.gray400
                      : AppTheme.gray600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple blocked-state for Alumni attempting to open the Student Portfolio
/// editing workflow (Task §5: "If a Portfolio route is manually accessed by
/// an Alumni, handle it safely").
class _StudentPortfolioBlockedView extends StatelessWidget {
  const _StudentPortfolioBlockedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Portfolio'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 64,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(height: AppTheme.space16),
              Text(
                'Portfolios are for Students',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.gray900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space12),
              Text(
                'As an Alumni you can keep a lightweight profile, get an '
                'optional AI Resume Review, and join the Alumni Community.',
                style: AppTheme.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.gray400
                      : AppTheme.gray600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.space24),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(alumniGroupChatRoute),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open Alumni Community'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isInitialized = false;
  bool _isLoggedOut = false; // V6.3: Track logout to prevent race conditions
  bool _providerInitScheduled =
      false; // Prevent double-scheduling init callbacks

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    await AuthService.firebase().initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// v7.1: Route to the correct dashboard based on user role
  /// v7.3: Students now use proper StudentDashboardView instead of legacy NotesView
  Widget _buildDashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.alumni:
        return const AlumniDashboardView();
      case UserRole.teacher:
        return const TeacherDashboardView();
      case UserRole.student:
      case null:
        // v7.3: Students use proper role-based dashboard architecture
        return const StudentDashboardView();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder(
      stream: AuthService.firebase().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          // V6.3 fix: Reset logout flag when a valid user is detected
          if (_isLoggedOut) {
            _isLoggedOut = false;
            _providerInitScheduled = false; // Allow fresh init on re-login
          }

          if (user.isEmailVerified) {
            return Consumer2<ProfileProvider, RoleProvider>(
              builder: (context, profileProvider, roleProvider, child) {
                // Initialize profile and role if not done
                if (!profileProvider.isInitialized && !_providerInitScheduled) {
                  _providerInitScheduled = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_isLoggedOut || !mounted) {
                      return; // V6.3: Don't init if logged out
                    }

                    final placementsProvider = context
                        .read<PlacementsProvider>();
                    final aiProvider = context.read<AIUsageProvider>();
                    final notificationsProvider = context
                        .read<NotificationsProvider>();
                    final resumeReviewProvider = context
                        .read<ResumeReviewProvider>(); // v6.7
                    final rp = context.read<RoleProvider>(); // v7.1
                    final chatProvider = context.read<ChatProvider>(); // v7.3
                    final aiChatProvider = context
                        .read<AIChatProvider>(); // v7.4
                    final alumniGroupChatProvider = context
                        .read<AlumniGroupChatProvider>(); // v8.7

                    placementsProvider.initWithUser(user.id);
                    aiProvider.initWithUser(user.id);
                    notificationsProvider.initWithUser(user.id);
                    resumeReviewProvider.initWithUser(user.id); // v6.7
                    rp.initWithUser(user.id); // v7.1
                    chatProvider.initWithUser(user.id); // v7.3
                    aiChatProvider.initWithUser(user.id); // v7.4
                    alumniGroupChatProvider.initWithUser(user.id); // v8.7
                    // v7.2: Initialize ecosystem providers after role is loaded
                    // This will be done in a separate callback below
                    profileProvider.initWithUser(
                      user.id,
                      user.email ?? 'noemail@example.com',
                    );
                  });

                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // v6.5: Sync profile to placements provider for eligibility checks
                // Use addPostFrameCallback to avoid calling during build
                if (profileProvider.hasProfile) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _isLoggedOut) return;
                    final placementsProvider = context
                        .read<PlacementsProvider>();
                    placementsProvider.updateUserProfile(
                      profileProvider.profile!,
                    );
                  });
                }

                // v7.2: Initialize ecosystem providers after role is loaded
                if (profileProvider.hasProfile && roleProvider.hasRole) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _isLoggedOut) return;
                    final mentorshipProvider = context
                        .read<MentorshipProvider>();
                    final opportunityProvider = context
                        .read<OpportunityProvider>();
                    final recommendationProvider = context
                        .read<RecommendationProvider>();
                    final engagementProvider = context
                        .read<EngagementProvider>();
                    final portfolioProvider = context
                        .read<PortfolioProvider>(); // v8.4
                    // v8.8.2 (B): the alumni group-chat stream is activated
                    // ONLY once the role is resolved — a non-alumni user
                    // (student/teacher) never subscribes, so no guaranteed
                    // PERMISSION_DENIED stream error appears every session.
                    final alumniGroupChatProvider = context
                        .read<AlumniGroupChatProvider>(); // v8.8.2
                    alumniGroupChatProvider.setRoleForStream(roleProvider.role);

                    final roleString = roleProvider.role?.name ?? 'student';

                    if (!mentorshipProvider.isInitialized) {
                      mentorshipProvider.initWithUser(user.id, roleString);
                    }
                    if (!opportunityProvider.isInitialized) {
                      opportunityProvider.initWithUser(user.id, roleString);
                    }

                    if (!recommendationProvider.isInitialized) {
                      recommendationProvider.initWithUser(
                        user.id,
                        profileProvider.profile!,
                      );
                    }
                    if (!engagementProvider.isInitialized) {
                      engagementProvider.initWithUser(
                        user.id,
                        profileProvider.profile!,
                      );
                    }
                    // v8.4: Initialize portfolio for students (loads empty portfolio for other roles)
                    if (!portfolioProvider.isInitialized) {
                      portfolioProvider.initWithUser(user.id);
                    }
                  });
                }

                if (profileProvider.isLoading || roleProvider.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!profileProvider.isProfileCompleted) {
                  return const ProfileSetupView();
                }

                // v7.1: Route based on role
                return _buildDashboardForRole(roleProvider.role);
              },
            );
          } else {
            return const VerifyEmailView();
          }
        } else {
          // V6.3: Reset providers on logout (only once)
          if (!_isLoggedOut) {
            _isLoggedOut = true;
            _providerInitScheduled = false;
            // Safety net: reset providers in case logout didn't come from a view
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_isLoggedOut) return;
              context.read<ProfileProvider>().reset();
              context.read<PlacementsProvider>().reset();
              context.read<AIUsageProvider>().reset();
              context.read<NotificationsProvider>().reset();
              context.read<ResumeReviewProvider>().reset();
              context.read<RoleProvider>().reset();
              // v7.2: Reset ecosystem providers
              context.read<MentorshipProvider>().reset();
              context.read<OpportunityProvider>().reset();
              context.read<AlumniDirectoryProvider>().reset();
              // v7.3: Reset chat provider
              context.read<ChatProvider>().reset();
              // v7.3: Reset teacher analytics provider
              context.read<TeacherAnalyticsProvider>().reset();
              // v7.3: Reset activity feed provider
              context.read<ActivityFeedProvider>().reset();
              // v7.4: Reset recommendation/engagement/AI chat providers
              context.read<RecommendationProvider>().reset();
              context.read<EngagementProvider>().reset();
              context.read<AIChatProvider>().reset();
              // v8.4: Reset portfolio provider
              context.read<PortfolioProvider>().reset();
              // v8.7: Reset alumni group chat provider
              context.read<AlumniGroupChatProvider>().reset();
            });
          }

          return const LoginView();
        }
      },
    );
  }
}
