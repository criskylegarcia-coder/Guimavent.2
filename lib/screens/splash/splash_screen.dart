import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/auth_guard.dart';
import '../../theme/app_theme.dart';
import '../../utils/onboarding_prefs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      // First launch ever? Show the onboarding walkthrough before
      // Welcome/Login — see utils/onboarding_prefs.dart.
      final seenOnboarding = await hasSeenOnboarding();
      if (!mounted) return;
      if (!seenOnboarding) {
        context.go('/onboarding');
        return;
      }
      // Already signed in? Skip straight past Welcome/Login.
      context.go(hasAuthSession() ? '/home' : '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on,
              size: 90,
              color: AppColors.white,
            ),
            const SizedBox(height: 20),
            Text(
              'GuimaVent',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 34,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Explore Guimaras with Confidence',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }
}