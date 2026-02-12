import 'package:campusconnect/providers/ai_usage_provider.dart';
import 'package:campusconnect/providers/notifications_provider.dart';
import 'package:campusconnect/providers/placements_provider.dart';
import 'package:campusconnect/providers/profile_provider.dart';
import 'package:campusconnect/providers/resume_review_provider.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.blueAccent[400],
      ),
      body: Column(
        children: [
          Text(
            "We've sent you an email verification. please open it to verify your email.",
          ),
          Text(
            "If you haven't received a verification email yet, press the button below.",
          ),
          TextButton(
            onPressed: () async {
              await AuthService.firebase().sendEmailVerification();
            },
            child: const Text('Send Email Verification'),
          ),
          TextButton(
            onPressed: () async {
              // CRITICAL: Reset all providers BEFORE logout to prevent data leakage
              context.read<ProfileProvider>().reset();
              context.read<PlacementsProvider>().reset();
              context.read<AIUsageProvider>().reset();
              context.read<NotificationsProvider>().reset();
              context.read<ResumeReviewProvider>().reset(); // v6.7
              await AuthService.firebase().logOut();
              // AuthGuard handles navigation via StreamBuilder
            },
            child: Text('Login'),
          ),
        ],
      ),
    );
  }
}
