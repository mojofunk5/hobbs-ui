import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/session.dart';
import 'package:hobbs_ui/screens/list_flight_entries_screen.dart';

void main() {
  const session = Session(
    sessionId: 'session-1',
    pilotId: 'pilot-1',
    name: 'William',
    admin: false,
  );

  String entryJson(String id, String departure, String arrival, String date) =>
      '{'
      '"id":"$id",'
      '"aircraftId":"aircraft-1",'
      '"flightTrackId":null,'
      '"date":"$date",'
      '"departureAirfieldId":"$departure",'
      '"departureTime":"${date}T10:00:00Z",'
      '"arrivalAirfieldId":"$arrival",'
      '"arrivalTime":"${date}T10:45:00Z",'
      '"pilotInCommandId":"pilot-2",'
      '"coPilotId":null,'
      '"singleEngineMinutes":45,'
      '"multiEngineMinutes":0,'
      '"totalMinutes":45,'
      '"nightMinutes":0,'
      '"ifrMinutes":0,'
      '"crossCountryMinutes":0,'
      '"pilotInCommandMinutes":45,'
      '"coPilotMinutes":0,'
      '"dualMinutes":0,'
      '"instructorMinutes":0,'
      '"dayLandings":3,'
      '"nightLandings":0,'
      '"remarks":null'
      '}';

  Future<void> pumpScreen(WidgetTester tester, {http.Client? client}) async {
    await tester.pumpWidget(MaterialApp(
      home: ListFlightEntriesScreen(session: session, httpClient: client),
    ));
  }

  testWidgets('shows every entry returned by the backend', (tester) async {
    final client = MockClient((request) async => http.Response(
        '[${entryJson('entry-1', 'EGCM', 'EGCC', '2026-08-24')},'
        '${entryJson('entry-2', 'EGCC', 'EGCM', '2026-08-20')}]',
        200));

    await pumpScreen(tester, client: client);
    await tester.pumpAndSettle();

    expect(find.text('EGCM → EGCC'), findsOneWidget);
    expect(find.text('EGCC → EGCM'), findsOneWidget);
    expect(find.text('2026-08-24'), findsOneWidget);
    expect(find.text('2026-08-20'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no entries', (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpScreen(tester, client: client);
    await tester.pumpAndSettle();

    expect(find.text('No flights logged yet.'), findsOneWidget);
  });

  testWidgets('shows an error with a retry button on failure', (tester) async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return requestCount == 1
          ? http.Response('', 500)
          : http.Response(
              '[${entryJson('entry-1', 'EGCM', 'EGCC', '2026-08-24')}]', 200);
    });

    await pumpScreen(tester, client: client);
    await tester.pumpAndSettle();

    expect(
        find.text('Could not load flight entries (HTTP 500).'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('EGCM → EGCC'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to the entry detail screen',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/flight')) {
        return http.Response(
            '[${entryJson('entry-1', 'EGCM', 'EGCC', '2026-08-24')}]', 200);
      }
      return http.Response(
          entryJson('entry-1', 'EGCM', 'EGCC', '2026-08-24'), 200);
    });

    await pumpScreen(tester, client: client);
    await tester.pumpAndSettle();

    await tester.tap(find.text('EGCM → EGCC'));
    await tester.pumpAndSettle();

    expect(find.text('View a flight'), findsOneWidget);
    expect(find.text('pilot-2'), findsOneWidget);
  });
}
