import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/screens/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLoginScreen(WidgetTester tester,
      {http.Client? client}) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(httpClient: client)));
  }

  testWidgets('does not submit when fields are empty', (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response('', 200);
    });

    await pumpLoginScreen(tester, client: client);
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(requestMade, isFalse);
  });

  testWidgets('shows an invalid-credentials error on a 401 response',
      (tester) async {
    final client = MockClient((request) async => http.Response('', 401));

    await pumpLoginScreen(tester, client: client);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'wills@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Invalid email/password combination.'), findsOneWidget);
  });
}
