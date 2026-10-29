import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A smooth, consistent page transition for the Splash/Welcome/Login/
/// Signup flow: fade in combined with a slight slide from the right, in
/// place of go_router's untouched default (MaterialPage's platform
/// transition — Android's Material 3 ZoomPageTransitionsBuilder), which
/// can read as an abrupt fade/zoom-through between full solid-color
/// screens like Splash and Welcome.
CustomTransitionPage<void> fadeSlideTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
