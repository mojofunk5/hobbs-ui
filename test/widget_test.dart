import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/main.dart';

void main() {
  testWidgets('shows a loading state before the health check resolves', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HobbsApp());
    // Exactly one pump: lets StartupScreen's SessionStore.load() resolve and HealthCheckPage
    // mount (still showing its initial "loading" state) - a second pump would also flush
    // HealthCheckPage's own health-check future, moving past the state this test checks for.
    await tester.pump();

    expect(find.text('Checking backend...'), findsOneWidget);
  });
}
