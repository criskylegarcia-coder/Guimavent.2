// lib/main.dart now boots straight into appRouter/AppTheme.light itself
// (splash -> auth -> the new shell, all via go_router), so this file is
// redundant for previewing purposes — kept around for now only because it
// skips Supabase.initialize(), which can be handy for quick UI-only runs.
// Safe to delete once that's no longer useful. Run it with:
//
//   flutter run -t lib/main_preview.dart

import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'router/auth_guard.dart';
import 'theme/app_theme.dart';

void main() {
  // appRouter's redirect guard and SplashScreen both check for a real
  // Supabase session — fake one here since this entry point never calls
  // Supabase.initialize(), so it can keep previewing the shell without it.
  authSessionOverride = () => true;
  runApp(const GuimaVentPreviewApp());
}

class GuimaVentPreviewApp extends StatelessWidget {
  const GuimaVentPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GuimaVent (Preview)',
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
