import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/airfield.dart';
import 'package:hobbs_ui/widgets/airfield_picker.dart';

void main() {
  const sherburn = Airfield(
    id: 'airfield-1',
    icaoCode: 'EGCJ',
    name: 'Sherburn-in-Elmet Airfield',
    municipality: 'Sherburn-in-Elmet',
    isoCountry: 'GB',
    isoRegion: 'GB-ENG',
    latitude: 53.79,
    longitude: -1.23,
    elevationFt: 20,
    type: 'small_airport',
  );

  Future<void> pumpPicker(
    WidgetTester tester, {
    required http.Client client,
    required ValueChanged<Airfield?> onChanged,
    Airfield? initialValue,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AirfieldPicker(
          sessionId: 'session-1',
          label: 'Departure place',
          httpClient: client,
          initialValue: initialValue,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets(
      'gaining focus loads the backend-ranked airfield set as suggestions',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/airfield'));
      expect(request.url.queryParameters['search'], isNull);
      return http.Response(
          '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
          '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
          '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
          200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('EGCJ - Sherburn-in-Elmet Airfield'), findsOneWidget);
  });

  testWidgets('typing debounces and searches by the entered text',
      (tester) async {
    final queries = <String?>[];
    final client = MockClient((request) async {
      queries.add(request.url.queryParameters['search']);
      return http.Response(
          '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
          '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
          '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
          200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'sherb');
    // Not yet - still within the debounce window.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(queries, contains('sherb'));
    expect(find.text('EGCJ - Sherburn-in-Elmet Airfield'), findsOneWidget);
  });

  testWidgets(
      'shows the searching indicator from the keystroke, not just once the debounced search starts',
      (tester) async {
    final client = MockClient((request) async => http.Response(
        '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
        '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
        '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
        200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.enterText(find.byType(TextField), 'sherb');
    await tester.pump();
    // Still within the debounce window - no request has fired yet, but the spinner should
    // already be visible so typing doesn't look like it did nothing.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'an earlier request resolving after a later one does not overwrite the fresher results',
      (tester) async {
    final completers = <String, Completer<http.Response>>{};
    final client = MockClient((request) async {
      final query = request.url.queryParameters['search'];
      if (query == null || query.isEmpty) {
        // The initial on-focus load, irrelevant to this race - resolve it immediately.
        return http.Response('[]', 200);
      }
      return completers.putIfAbsent(query, Completer<http.Response>.new).future;
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Two searches end up in flight at once - typing "sh", pausing long enough for its debounced
    // search to fire, then typing on to "sher" and pausing again before the first has responded.
    await tester.enterText(find.byType(TextField), 'sh');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'sher');
    await tester.pump(const Duration(milliseconds: 350));

    // Resolve out of order: the later, more specific request ("sher") finishes first; the
    // earlier, now-stale request ("sh") finishes after it. The stale response must not win.
    completers['sher']!.complete(http.Response(
        '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
        '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
        '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
        200));
    await tester.pump();
    completers['sh']!.complete(http.Response('[]', 200));
    await tester.pump();

    expect(find.text('EGCJ - Sherburn-in-Elmet Airfield'), findsOneWidget);
  });

  testWidgets('selecting a suggestion calls onChanged and fills the field',
      (tester) async {
    Airfield? selected;
    final client = MockClient((request) async => http.Response(
        '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
        '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
        '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
        200));

    await pumpPicker(tester, client: client,
        onChanged: (airfield) => selected = airfield);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('EGCJ - Sherburn-in-Elmet Airfield'));
    await tester.pump();

    expect(selected, sherburn);
    expect(find.widgetWithText(TextField, 'EGCJ - Sherburn-in-Elmet Airfield'),
        findsOneWidget);
    // The suggestion list is dismissed once something's selected.
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
      'tapping the clear icon removes the selection and reopens the suggestion list',
      (tester) async {
    Airfield? selected;
    final client = MockClient((request) async => http.Response(
        '[{"id":"airfield-1","icaoCode":"EGCJ","name":"Sherburn-in-Elmet Airfield",'
        '"municipality":"Sherburn-in-Elmet","isoCountry":"GB","isoRegion":"GB-ENG",'
        '"latitude":53.79,"longitude":-1.23,"elevationFt":20,"type":"small_airport"}]',
        200));

    await pumpPicker(tester, client: client,
        onChanged: (airfield) => selected = airfield);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('EGCJ - Sherburn-in-Elmet Airfield'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(selected, isNull);
    expect(find.widgetWithText(TextField, 'EGCJ - Sherburn-in-Elmet Airfield'),
        findsNothing);
    // Reopens the full suggestion set immediately, rather than leaving an empty field with
    // nothing to pick until the pilot types something first.
    expect(find.text('EGCJ - Sherburn-in-Elmet Airfield'), findsOneWidget);
  });

  testWidgets(
      'falls back to just the name when the airfield has no icao code',
      (tester) async {
    final client = MockClient((request) async => http.Response(
        '[{"id":"airfield-2","icaoCode":null,"name":"Some Strip",'
        '"municipality":"Nowhere","isoCountry":"GB","isoRegion":"GB-ENG",'
        '"latitude":1.0,"longitude":2.0,"elevationFt":null,"type":"small_airport"}]',
        200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('Some Strip'), findsOneWidget);
  });

  testWidgets('starts pre-filled with an initial value', (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(
      tester,
      client: client,
      onChanged: (_) {},
      initialValue: sherburn,
    );

    expect(find.widgetWithText(TextField, 'EGCJ - Sherburn-in-Elmet Airfield'),
        findsOneWidget);
  });

  testWidgets('shows a no-matches hint when a search returns nothing',
      (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Sherbrun');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No airfields found - check the spelling and try again'),
        findsOneWidget);
  });

  testWidgets('editing the text clears a prior selection until a new pick',
      (tester) async {
    Airfield? selected = sherburn;
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(
      tester,
      client: client,
      onChanged: (airfield) => selected = airfield,
      initialValue: sherburn,
    );
    await tester.enterText(find.byType(TextField), 'EGC');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(selected, isNull);
  });
}
