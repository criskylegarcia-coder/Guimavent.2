import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import '../../utils/app_info.dart';
import '../../utils/logout_confirmation.dart';
import '../../widgets/primary_button.dart';

// Reached from Profile's Settings icon. Deliberately minimal beyond the
// appearance toggle: there's no other genuinely-functional account setting
// wired up yet (no change-password flow, no notification preferences to
// persist), so this only surfaces what's real — dark mode, the app
// version, and Log out — rather than padding the screen with fake toggles.
class SettingsScreen extends StatelessWidget {
  // Overridable for tests; every real call site leaves this null and gets
  // the real app-wide controller (see theme/theme_controller.dart).
  final ThemeController? controller;

  const SettingsScreen({super.key, this.controller});

  ThemeController get _controller => controller ?? themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: _controller,
                    builder: (context, mode, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                        ],
                        selected: {mode},
                        showSelectedIcon: false,
                        onSelectionChanged: (modes) =>
                            _controller.setThemeMode(modes.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('App Version'),
              trailing: Text(appVersion, style: theme.textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Log Out',
            onPressed: () => confirmAndLogout(context),
          ),
        ],
      ),
    );
  }
}
