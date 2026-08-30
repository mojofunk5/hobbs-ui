import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/aircraft.dart';
import 'package:hobbs_ui/widgets/aircraft_picker.dart';

void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required http.Client client,
    required ValueChanged<Aircraft?> onChanged,
    Aircraft? initialValue,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AircraftPicker(
          sessionId: 'session-1',
          label: 'Aircraft',
          httpClient: client,
          initialValue: initialValue,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets('does not search until at least 2 characters are typed',
      (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('[]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'g');
    await tester.pump(const Duration(milliseconds: 350));

    expect(requests, 0);
  });

  testWidgets('typing 2+ characters debounces and searches registration only',
      (tester) async {
    final queries = <String?>[];
    final registrationOnlyValues = <String?>[];
    final client = MockClient((request) async {
      queries.add(request.url.queryParameters['search']);
      registrationOnlyValues.add(request.url.queryParameters['registrationOnly']);
      return http.Response(
          '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 100));
    // Not yet - still within the debounce window.
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));

    expect(queries, contains('ab'));
    expect(registrationOnlyValues, contains('true'));
    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
  });

  testWidgets('shows a no-matches message when the search returns nothing',
      (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No aircraft found for that registration'), findsOneWidget);
  });

  testWidgets('selecting a suggestion fills the field and calls onChanged',
      (tester) async {
    Aircraft? selected;
    final client = MockClient((request) async => http.Response(
        '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200));

    await pumpPicker(tester, client: client, onChanged: (a) => selected = a);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('G-ABCD - Cessna 152'));
    await tester.pump();

    expect(selected?.id, 'aircraft-1');
    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('editing the text after a selection clears it', (tester) async {
    Aircraft? selected = const Aircraft(id: 'x', registration: 'G-XXXX');
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(
      tester,
      client: client,
      onChanged: (a) => selected = a,
      initialValue: const Aircraft(id: 'x', registration: 'G-XXXX'),
    );
    await tester.enterText(find.byType(TextField), 'G-XXXX2');
    await tester.pump();

    expect(selected, isNull);
  });
}
