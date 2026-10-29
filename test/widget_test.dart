// Smoke test: confirms the real app (GuimaVentApp) boots through splash and
// lands on Welcome without throwing. Uses authSessionOverride (the same
// seam main_preview.dart relies on) so this doesn't need a live Supabase
// connection or Supabase.initialize() in the test environment.

import 'package:flutter_test/flutter_test.dart';

import 'package:guimavent/main.dart';
import 'package:guimavent/router/auth_guard.dart';

void main() {
  testWidgets('GuimaVentApp boots and reaches Welcome without throwing', (
    WidgetTester tester,
  ) async {
    authSessionOverride = () => false;
    addTearDown(() => authSessionOverride = null);

    await tester.pumpWidget(const GuimaVentApp());
    expect(tester.takeException(), isNull);

    // Let the splash screen's timer fire and navigate to /welcome.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    expect(find.text('GuimaVent'), findsOneWidget);
  });
}
