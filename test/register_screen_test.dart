import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/screens/register_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpRegisterScreen(WidgetTester tester,
      {http.Client? client}) async {
    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(httpClient: client)),
    );
  }

  testWidgets('does not submit when fields are empty', (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response('', 201);
    });

    await pumpRegisterScreen(tester, client: client);
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(requestMade, isFalse);
  });

  testWidgets('shows a referral-code error on a 403 response', (tester) async {
    final client = MockClient((request) async => http.Response('', 403));

    await pumpRegisterScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField).at(0), 'Wills');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'wills@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'bad-code');
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
    await tester.pump();

    expect(find.text('That referral code is invalid or has already been used.'),
        findsOneWidget);
  });
}
