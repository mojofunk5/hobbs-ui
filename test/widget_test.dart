import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/main.dart';

void main() {
  testWidgets('shows the welcome screen when no session is persisted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HobbsApp());
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('shows the signed-in screen when a session is already persisted',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'hobbs_session':
          '{"sessionId":"s","pilotId":"p","name":"Wills","admin":false}',
    });

    await tester.pumpWidget(const HobbsApp());
    await tester.pump();

    expect(find.text('Signed in as Wills'), findsOneWidget);
  });
}
