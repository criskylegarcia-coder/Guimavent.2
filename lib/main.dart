import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

 await Supabase.initialize(
  url: 'https://aprcalualpiptrixqcar.supabase.co',
  publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwcmNhbHVhbHBpcHRyaXhxY2FyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ4NTY3NjcsImV4cCI6MjEwMDQzMjc2N30.7ejcu_Sji9x98bkczQcZ9dwrjbOg1eP_SRYiAOk2PAQ',
);

debugPrint("URL:");
debugPrint('https://aprcalualpiptrixqcar.supabase.co');

await themeController.load();

runApp(const GuimaVentApp());
}
class GuimaVentApp extends StatelessWidget {
  const GuimaVentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'GuimaVent',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}