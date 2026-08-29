import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hobbs_ui/screens/reset_password_screen.dart';
import 'package:hobbs_ui/widgets/otp_code_input.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpResetScreen(WidgetTester tester,
      {http.Client? client}) async {
    await tester
        .pumpWidget(MaterialApp(home: ResetPasswordScreen(httpClient: client)));
  }

  testWidgets('does not submit the request step with an invalid email',
      (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response('', 200);
    });

    await pumpResetScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(requestMade, isFalse);
  });

  testWidgets('a successful request moves to the confirm step', (tester) async {
    final client = MockClient((request) async => http.Response('', 200));

    await pumpResetScreen(tester, client: client);
    await tester.enterText(
        find.byType(TextFormField).first, 'wills@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    expect(find.text('Reset password'), findsWidgets);
    expect(find.text('New password'), findsOneWidget);
  });

  testWidgets(
      'a generic error shows on a failed request, not an enumerating one',
      (tester) async {
    final client = MockClient((request) async => http.Response('', 500));

    await pumpResetScreen(tester, client: client);
    await tester.enterText(
        find.byType(TextFormField).first, 'wills@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('a 400 on confirm shows one generic message', (tester) async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      // First call is the request step (200), second is confirm (400).
      return http.Response('', callCount == 1 ? 200 : 400);
    });

    await pumpResetScreen(tester, client: client);
    await tester.enterText(
        find.byType(TextFormField).first, 'wills@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset code'));
    await tester.pump();

    final otpBoxes = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    for (var i = 0; i < 6; i++) {
      await tester.enterText(otpBoxes.at(i), '$i');
    }
    // TextFormField 0 is the disabled email field, 1 is the new-password field - the OTP boxes are
    // plain TextFields, not TextFormFields, so they don't shift this index.
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassw0rd');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pump();

    expect(
      find.text('Invalid or expired code, or the new password was rejected.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'a deep link with email and code jumps straight to a locked confirm step',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResetPasswordScreen(
            initialEmail: 'wills@example.com', initialCode: '123456'),
      ),
    );

    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Send reset code'), findsNothing);

    final emailField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(emailField.enabled, isFalse);
    expect(emailField.initialValue, 'wills@example.com');

    final otpBoxes = find.descendant(
      of: find.byType(OtpCodeInput),
      matching: find.byType(TextField),
    );
    for (var i = 0; i < 6; i++) {
      final box = tester.widget<TextField>(otpBoxes.at(i));
      expect(box.enabled, isFalse);
      expect(box.controller?.text, '123456'[i]);
    }
  });
}
