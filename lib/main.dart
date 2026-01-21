import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/firebase_options.dart';
import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/services/firestore/placements_service.dart';
import 'package:campusconnect/views/login_view.dart';
import 'package:campusconnect/views/notes_view.dart';
import 'package:campusconnect/views/profile_view.dart';
import 'package:campusconnect/views/register_view.dart';
import 'package:campusconnect/views/verify_email_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // V5.1.1: Providers at root level - persist across auth changes
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              PlacementsProvider(service: PlacementsService.instance()),
        ),
        ChangeNotifierProvider(
          create: (_) => AIUsageProvider(aiService: AIService.instance()),
        ),
      ],
      child: MaterialApp(
        title: 'CampusConnect',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const HomePage(),
        routes: {
          loginRoute: (context) => const LoginView(),
          registerRoute: (context) => const RegisterView(),
          notesRoute: (context) => const NotesView(),
          verifyEmailRoute: (context) => const VerifyEmailView(),
          profileRoute: (context) => const ProfileView(),
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService.firebase().initialize(),
      builder: (context, asyncSnapshot) {
        switch (asyncSnapshot.connectionState) {
          case ConnectionState.done:
            final user = AuthService.firebase().currentUser;
            if (user != null) {
              if (user.isEmailVerified) {
                // V5.1.1: Initialize providers with userId
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final placementsProvider = context.read<PlacementsProvider>();
                  final aiProvider = context.read<AIUsageProvider>();

                  // Only init if not already initialized or userId changed
                  placementsProvider.initWithUser(user.id);
                  aiProvider.initWithUser(user.id);
                });

                return const NotesView();
              } else {
                return const VerifyEmailView();
              }
            } else {
              // V5.1.1: Reset providers on logout
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<PlacementsProvider>().reset();
                context.read<AIUsageProvider>().reset();
              });

              return const LoginView();
            }
          default:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}
