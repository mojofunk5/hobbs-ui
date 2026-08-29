import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hobbs_ui/widgets/otp_code_input.dart';

void main() {
  testWidgets('typing a digit in each box in turn assembles the full code',
      (tester) async {
    var code = '';
    await tester.pumpWidget(
      MaterialApp(
          home:
              Scaffold(body: OtpCodeInput(onChanged: (value) => code = value))),
    );

    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '$i');
      await tester.pump();
    }

    expect(code, '012345');
  });

  testWidgets(
      'backspace on an empty box steps back and clears the previous one',
      (tester) async {
    var code = '';
    await tester.pumpWidget(
      MaterialApp(
          home:
              Scaffold(body: OtpCodeInput(onChanged: (value) => code = value))),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.pump();
    // Focus is now on box 1 (empty) after box 0's auto-advance - backspace here should clear box 0
    // and move focus back to it.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();

    expect(code, '');
  });

  testWidgets('pasting a full code distributes it across all boxes',
      (tester) async {
    var code = '';
    await tester.pumpWidget(
      MaterialApp(
          home:
              Scaffold(body: OtpCodeInput(onChanged: (value) => code = value))),
    );

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.pump();

    expect(code, '123456');
  });
}
