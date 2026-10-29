// Admin Web Portal entry point — a separate Flutter Web app from
// lib/main.dart (the tourist app), sharing the same Supabase backend and
// lib/models//lib/repositories/ but with its own router, screens (lib/admin/),
// and auth flow (staff-only, no public signup). Run with:
//
//   flutter run -d chrome -t lib/main_admin.dart
//
// or build with:
//
//   flutter build web -t lib/main_admin.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/router/admin_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aprcalualpiptrixqcar.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwcmNhbHVhbHBpcHRyaXhxY2FyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4NTY3NjcsImV4cCI6MjEwMDQzMjc2N30.7ejcu_Sji9x98bkczQcZ9dwrjbOg1eP_SRYiAOk2PAQ',
  );

  runApp(const GuimaVentAdminApp());
}

class GuimaVentAdminApp extends StatelessWidget {
  const GuimaVentAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GuimaVent Admin',
      theme: AppTheme.light,
      routerConfig: adminRouter,
    );
  }
}
