import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/enums/user_role.dart';
import 'package:campusconnect/firebase_options.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/role_provider.dart';
import 'package:campusconnect/providers/theme_provider.dart';
// v7.2: Multi-role ecosystem providers
import 'package:campusconnect/providers/alumni_directory_provider.dart';
import 'package:campusconnect/providers/mentorship_provider.dart';
import 'package:campusconnect/providers/opportunity_provider.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/ai/resume_review_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notifications_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/services/firestore/alumni_directory_service.dart';
import 'package:campusconnect/services/firestore/mentorship_service.dart';
import 'package:campusconnect/services/firestore/opportunity_service.dart';
import 'package:campusconnect/services/local_preferences_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/dashboards/alumni_dashboard_view.dart';
import 'package:campusconnect/views/dashboards/teacher_dashboard_view.dart';
import 'package:campusconnect/views/edit_profile_view.dart';
import 'package:campusconnect/views/login_view.dart';
import 'package:campusconnect/views/notes_view.dart';
import 'package:campusconnect/views/notifications_view.dart';
import 'package:campusconnect/views/profile_setup_view.dart';
import 'package:campusconnect/views/profile_view.dart';
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
import 'package:campusconnect/views/opportunities/opportunities_view.dart';
import 'package:campusconnect/views/opportunities/create_opportunity_view.dart';
import 'package:campusconnect/views/opportunities/opportunity_detail_view.dart';
import 'package:campusconnect/views/teacher/student_analytics_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // v6.6: Initialize local preferences service
  await LocalPreferencesService.instance().init();
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
          create: (_) =>
              AlumniDirectoryProvider(service: AlumniDirectoryService.instance()),
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
                final reviewId = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (context) =>
                      ResumeReviewDetailView(reviewId: reviewId),
                );
              }
              return null; // Let routes handle it
            },
            routes: {
              loginRoute: (context) => const LoginView(),
              registerRoute: (context) => const RegisterView(),
              notesRoute: (context) => const NotesView(),
              verifyEmailRoute: (context) => const VerifyEmailView(),
              profileRoute: (context) => const ProfileView(),
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
              studentDashboardRoute: (context) => const NotesView(), // v7.2: Redirect to Notes
              alumniDashboardRoute: (context) => const AlumniDashboardView(),
              teacherDashboardRoute: (context) => const TeacherDashboardView(),
              // v7.2: Multi-role ecosystem routes
              alumniDirectoryRoute: (context) => const AlumniDirectoryView(),
              alumniProfileRoute: (context) => const AlumniProfileView(),
              mentorshipRequestsRoute: (context) => const MentorshipRequestsView(),
              createMentorshipRequestRoute: (context) => const CreateMentorshipRequestView(),
              mentorshipRequestDetailRoute: (context) => const MentorshipRequestDetailView(),
              opportunitiesRoute: (context) => const OpportunitiesView(),
              createOpportunityRoute: (context) => const CreateOpportunityView(),
              opportunityDetailRoute: (context) => const OpportunityDetailView(),
              studentAnalyticsRoute: (context) => const StudentAnalyticsView(),
            },
          );
        },
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
  /// v7.2: Students use enhanced NotesView as main dashboard with Connect & Grow features
  Widget _buildDashboardForRole(UserRole? role) {
    switch (role) {
      case UserRole.alumni:
        return const AlumniDashboardView();
      case UserRole.teacher:
        return const TeacherDashboardView();
      case UserRole.student:
      case null:
        // v7.2: Students use enhanced NotesView with Connect & Grow ecosystem
        return const NotesView();
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

                    placementsProvider.initWithUser(user.id);
                    aiProvider.initWithUser(user.id);
                    notificationsProvider.initWithUser(user.id);
                    resumeReviewProvider.initWithUser(user.id); // v6.7
                    rp.initWithUser(user.id); // v7.1
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
                    final mentorshipProvider = context.read<MentorshipProvider>();
                    final opportunityProvider = context.read<OpportunityProvider>();

                    final roleString = roleProvider.role?.name ?? 'student';

                    if (!mentorshipProvider.isInitialized) {
                      mentorshipProvider.initWithUser(user.id, roleString);
                    }
                    if (!opportunityProvider.isInitialized) {
                      opportunityProvider.initWithUser(user.id, roleString);
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
            });
          }

          return const LoginView();
        }
      },
    );
  }
}
