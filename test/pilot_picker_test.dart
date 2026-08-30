import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/pilot_summary.dart';
import 'package:hobbs_ui/widgets/pilot_picker.dart';

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required http.Client client,
    required ValueChanged<PilotSummary?> onChanged,
    PilotSummary? initialValue,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PilotPicker(
          sessionId: 'session-1',
          label: 'Pilot in command',
          httpClient: client,
          initialValue: initialValue,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets('gaining focus loads the caller\'s known pilots as suggestions',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/pilot'));
      expect(request.url.queryParameters['search'], isNull);
      return http.Response('[{"id":"pilot-2","name":"Louis"}]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('Louis'), findsOneWidget);
  });

  testWidgets('typing debounces and searches by the entered text',
      (tester) async {
    final queries = <String?>[];
    final client = MockClient((request) async {
      queries.add(request.url.queryParameters['search']);
      return http.Response('[{"id":"pilot-2","name":"Louis"}]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'lou');
    // Not yet - still within the debounce window.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(queries, contains('lou'));
    expect(find.text('Louis'), findsOneWidget);
  });

  testWidgets('selecting a suggestion calls onChanged and fills the field',
      (tester) async {
    PilotSummary? selected;
    final client = MockClient((request) async =>
        http.Response('[{"id":"pilot-2","name":"Louis"}]', 200));

    await pumpPicker(tester, client: client,
        onChanged: (pilot) => selected = pilot);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Louis'));
    await tester.pump();

    expect(selected, const PilotSummary(id: 'pilot-2', name: 'Louis'));
    expect(find.widgetWithText(TextField, 'Louis'), findsOneWidget);
    // The suggestion list is dismissed once something's selected.
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
      'no matches offers to create a new pilot with the typed name',
      (tester) async {
    PilotSummary? selected;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response('{"id":"pilot-3","name":"Amy"}', 201);
      }
      return http.Response('[]', 200);
    });

    await pumpPicker(tester, client: client,
        onChanged: (pilot) => selected = pilot);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Amy');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Create pilot "Amy"'), findsOneWidget);

    await tester.tap(find.text('Create pilot "Amy"'));
    await tester.pump();

    expect(selected, const PilotSummary(id: 'pilot-3', name: 'Amy'));
    expect(find.widgetWithText(TextField, 'Amy'), findsOneWidget);
  });

  testWidgets('starts pre-filled with an initial value', (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(
      tester,
      client: client,
      onChanged: (_) {},
      initialValue: const PilotSummary(id: 'pilot-1', name: 'William'),
    );

    expect(find.widgetWithText(TextField, 'William'), findsOneWidget);
  });

  testWidgets('editing the text clears a prior selection until a new pick',
      (tester) async {
    PilotSummary? selected = const PilotSummary(id: 'pilot-1', name: 'X');
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(
      tester,
      client: client,
      onChanged: (pilot) => selected = pilot,
      initialValue: const PilotSummary(id: 'pilot-1', name: 'William'),
    );
    await tester.enterText(find.byType(TextField), 'Wi');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(selected, isNull);
  });
}
