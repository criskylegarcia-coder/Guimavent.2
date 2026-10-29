import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/admin_auth_repository.dart';
import '../../repositories/repository_exception.dart';
import '../../theme/app_theme.dart';
import '../../widgets/password_field.dart';
import '../router/admin_auth_guard.dart';

// Staff sign-in for the admin portal. No public signup — accounts are
// created manually (Supabase dashboard, or a future super-admin flow, not
// in scope for Batch 1). A non-staff account that signs in successfully at
// the Supabase Auth level is still rejected here — see
// AdminAuthRepository.signIn(), which checks profiles.staff and signs the
// user back out if it's false, before this screen ever sees a success.
class AdminLoginScreen extends StatefulWidget {
  // Overridable for tests; every real call site leaves this null and gets
  // the real Supabase-backed repository.
  final AdminAuthRepository? repository;

  const AdminLoginScreen({super.key, this.repository});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  late final AdminAuthRepository _repository =
      widget.repository ?? SupabaseAdminAuthRepository();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _repository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      markStaffSessionVerified();
      if (mounted) context.go('/admin/dashboard');
    } catch (e) {
      setState(() {
        _errorMessage = e is RepositoryException
            ? e.message
            : 'Sign in failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'GuimaVent Admin',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Tourism Officer Portal',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _passwordController,
                  labelText: 'Password',
                  onSubmitted: (_) => _handleLogin(),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(_isLoading ? 'Signing in...' : 'Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
