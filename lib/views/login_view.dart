import 'package:campusconnect/constants/routes.dart';
import 'package:campusconnect/services/auth/auth_exceptions.dart';
import 'package:campusconnect/services/auth/auth_service.dart';
import 'package:campusconnect/utilities/show_error_dialog.dart';
import 'package:flutter/material.dart';


class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.blueAccent[400],
      ),
      body: Column(
        children: [
          TextField(
            controller: _email,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Enter your email here',
            ),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Enter Password'),
          ),
          TextButton(
            onPressed: () async {
              final email = _email.text.trim();
              final password = _password.text.trim();

              if (email.isEmpty || password.isEmpty) {
                if (!context.mounted) return;
                await showErrorDialog(
                  context,
                  'Email and password cannot be empty.',
                );
                return;
              }

              try {
                await AuthService.firebase().logIn(
                  email: email,
                  password: password,
                );

                final user = AuthService.firebase().currentUser;

                if (!context.mounted) return;

                if (user?.isEmailVerified ?? false) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(notesRoute, (_) => false);
                } else {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(verifyEmailRoute, (_) => false);
                }
              } on UserNotFoundAuthException {
                await showErrorDialog(
                  context,
                  'No account found for that email.',
                );
              } on WrongPasswordAuthException {
                await showErrorDialog(context, 'Incorrect password.');
              } on InvalidEmailAuthException {
                if (!context.mounted) return;
                await showErrorDialog(context, 'Incorrect email or password.');
              } on InvalidCredentialAuthException {
                if (!context.mounted) return;
                await showErrorDialog(context, 'Invalid credentials provided.');
              } on GenericAuthException {
                if (!context.mounted) return;
                await showErrorDialog(
                  context,
                  'Authentication error. Please try again.',
                );
              }
            },

            child: const Text('Login'),
          ),

          TextButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(registerRoute, (_) => false);
            },
            child: const Text('Not registered yet? Register here!'),
          ),
        ],
      ),
    );
  }
}
