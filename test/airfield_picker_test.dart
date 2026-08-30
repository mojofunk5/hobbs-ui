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
