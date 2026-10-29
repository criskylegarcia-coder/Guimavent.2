import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/password_field.dart';
import '../../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    // Simple validation muna
    if (_fullNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Full name is required.";
      });
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords do not match.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[Register] Calling signUp for ${_emailController.text.trim()}...');
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'full_name': _fullNameController.text.trim()},
      );
      debugPrint(
        '[Register] signUp returned. '
        'user=${response.user?.id}, '
        'identities=${response.user?.identities?.length}, '
        'session=${response.session != null ? "present" : "null"}',
      );

      if (response.user != null && mounted) {
        debugPrint('[Register] user non-null, showing snackbar + navigating to /login');
        // Successful account creation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! Please log in.")),
        );
        context.go('/login');
        debugPrint('[Register] context.go(\'/login\') called.');
      } else {
        debugPrint('[Register] Did NOT navigate. user=${response.user}, mounted=$mounted');
      }
    } on AuthException catch (e) {
      debugPrint('[Register] AuthException caught: "${e.message}" (statusCode=${e.statusCode})');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e, stack) {
      debugPrint('[Register] Unexpected exception: $e');
      debugPrint('[Register] Stack trace: $stack');
      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(hintText: "Full Name"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(hintText: "Email"),
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _passwordController,
              hintText: "Password",
              showBorder: false,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirmPasswordController,
              hintText: "Confirm Password",
              showBorder: false,
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            PrimaryButton(
              label: _isLoading ? "Creating account..." : "Register",
              onPressed: _isLoading ? null : _handleRegister,
            ),
          ],
        ),
      ),
    );
  }
}
