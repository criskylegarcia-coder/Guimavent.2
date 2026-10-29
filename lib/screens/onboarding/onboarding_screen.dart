import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/auth_guard.dart';
import '../../theme/app_theme.dart';
import '../../utils/onboarding_prefs.dart';
import '../../widgets/primary_button.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const List<_OnboardingPage> _pages = [
  _OnboardingPage(
    icon: Icons.explore_rounded,
    title: 'Discover Events & Activities',
    description:
        'Browse festivals, tours, and local activities happening across '
        "Guimaras' five municipalities.",
  ),
  _OnboardingPage(
    icon: Icons.checklist_rounded,
    title: 'Plan Your Itinerary',
    description:
        'Save the activities you love to My Schedule and build your own '
        'day-by-day plan as you go.',
  ),
  _OnboardingPage(
    icon: Icons.app_registration_rounded,
    title: 'Register for Arrival',
    description:
        'Complete a quick Pre-Arrival Registration to get your QR pass '
        'ready before you land.',
  ),
  _OnboardingPage(
    icon: Icons.directions_rounded,
    title: 'Get Directions',
    description:
        "Navigate straight to any activity's venue with real walking, "
        'cycling, or driving directions.',
  ),
];

// A short walkthrough shown once, on the very first launch (see
// SplashScreen and utils/onboarding_prefs.dart), before Welcome/Login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == _pages.length - 1;

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (!mounted) return;
    context.go(hasAuthSession() ? '/home' : '/welcome');
  }

  void _handleNext() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: TextButton(
                  onPressed: _isLastPage ? null : _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: _isLastPage
                          ? Colors.transparent
                          : AppColors.textDark.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _OnboardingPageView(page: _pages[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: PrimaryButton(
                label: _isLastPage ? 'Get Started' : 'Next',
                onPressed: _handleNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenPadding * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
