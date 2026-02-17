import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/firebase_options.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/layout_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/providers/theme_provider.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/ai/resume_review_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/notifications_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/services/local_preferences_service.dart';
import 'package:campusconnect/theme/app_theme.dart';
import 'package:campusconnect/views/edit_profile_view.dart';
import 'package:campusconnect/views/login_view.dart';
import 'package:campusconnect/views/notes_view.dart';
import 'package:campusconnect/views/notifications_view.dart';
import 'package:campusconnect/views/profile_setup_view.dart';
import 'package:campusconnect/views/profile_view.dart';
import 'package:campusconnect/views/register_view.dart';
import 'package:campusconnect/views/resume_review_detail_view.dart'; // v6.8
import 'package:campusconnect/views/resume_review_history_view.dart'; // v6.8
import 'package:campusconnect/views/resume_review_view.dart';
import 'package:campusconnect/views/settings_view.dart';
import 'package:campusconnect/views/verify_email_view.dart';
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

  void _handleLogout() {
    // V6.3: Set flag BEFORE resetting providers to prevent re-init
    _isLoggedOut = true;

    final placementsProvider = context.read<PlacementsProvider>();
    final aiProvider = context.read<AIUsageProvider>();
    final profileProvider = context.read<ProfileProvider>();
    final notificationsProvider = context.read<NotificationsProvider>();
    final resumeReviewProvider = context.read<ResumeReviewProvider>(); // v6.7

    placementsProvider.reset();
    aiProvider.reset();
    profileProvider.reset();
    notificationsProvider.reset();
    resumeReviewProvider.reset(); // v6.7
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
            return Consumer<ProfileProvider>(
              builder: (context, profileProvider, child) {
                // Initialize profile if not done
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

                    placementsProvider.initWithUser(user.id);
                    aiProvider.initWithUser(user.id);
                    notificationsProvider.initWithUser(user.id);
                    resumeReviewProvider.initWithUser(user.id); // v6.7
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

                if (profileProvider.isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!profileProvider.isProfileCompleted) {
                  return const ProfileSetupView();
                }

                return const NotesView();
              },
            );
          } else {
            return const VerifyEmailView();
          }
        } else {
          // V6.3: Reset providers on logout (only once)
          // Views already call reset() before logOut(), so only reset if not done
          if (!_isLoggedOut && user == null) {
            _isLoggedOut = true;
            _providerInitScheduled = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isLoggedOut) _handleLogout();
            });
          }

          return const LoginView();
        }
      },
    );
  }
}
