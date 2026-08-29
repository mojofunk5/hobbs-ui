import 'package:flutter_test/flutter_test.dart';

import 'package:hobbs_ui/main.dart';

void main() {
  testWidgets('shows a loading state before the health check resolves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HobbsApp());

    expect(find.text('Checking backend...'), findsOneWidget);
  });
}
