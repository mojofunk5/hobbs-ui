import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/session.dart';
import 'package:hobbs_ui/screens/view_flight_entry_screen.dart';

void main() {
  const session = Session(
    sessionId: 'session-1',
    pilotId: 'pilot-1',
    name: 'William',
    admin: false,
  );

  const entryJson = '{'
      '"id":"entry-1",'
      '"aircraftId":"aircraft-1",'
      '"flightTrackId":null,'
      '"date":"2026-08-24",'
      '"departurePlace":"EGCM",'
      '"departureTime":"2026-08-24T10:00:00Z",'
      '"arrivalPlace":"EGCC",'
      '"arrivalTime":"2026-08-24T10:45:00Z",'
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
      '"remarks":"Circuits"'
      '}';

  Future<void> pumpScreen(WidgetTester tester,
      {http.Client? client, String? initialFlightEntryId}) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewFlightEntryScreen(
        session: session,
        initialFlightEntryId: initialFlightEntryId,
        httpClient: client,
      ),
    ));
  }

  testWidgets('does not look up when the id field is empty', (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response(entryJson, 200);
    });

    await pumpScreen(tester, client: client);
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(requestMade, isFalse);
  });

  testWidgets('looking up an entry shows its details', (tester) async {
    final client = MockClient((request) async => http.Response(entryJson, 200));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField), 'entry-1');
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    await tester.pumpAndSettle();

    expect(find.text('EGCM 10:00'), findsOneWidget);
    expect(find.text('EGCC 10:45'), findsOneWidget);
    expect(find.text('pilot-2'), findsOneWidget);
    expect(find.text('Circuits'), findsOneWidget);
  });

  testWidgets('shows a not-found error on a 404 response', (tester) async {
    final client = MockClient((request) async => http.Response('', 404));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField), 'unknown-id');
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    await tester.pumpAndSettle();

    expect(find.text('No entry found with that id.'), findsOneWidget);
  });

  testWidgets('shows a forbidden error on a 403 response', (tester) async {
    final client = MockClient((request) async => http.Response('', 403));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField), 'someone-elses-entry');
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    await tester.pumpAndSettle();

    expect(
        find.text('That entry belongs to a different pilot.'), findsOneWidget);
  });

  testWidgets('an initial id is looked up automatically', (tester) async {
    var requestedPath = '';
    final client = MockClient((request) async {
      requestedPath = request.url.path;
      return http.Response(entryJson, 200);
    });

    await pumpScreen(tester, client: client, initialFlightEntryId: 'entry-1');
    await tester.pumpAndSettle();

    expect(requestedPath, endsWith('/flight/entry-1'));
    expect(find.text('EGCM 10:00'), findsOneWidget);
  });

  testWidgets('look up another clears the details and returns to the form',
      (tester) async {
    final client = MockClient((request) async => http.Response(entryJson, 200));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextFormField), 'entry-1');
    await tester.tap(find.widgetWithText(FilledButton, 'View'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.widgetWithText(OutlinedButton, 'Look up another'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Look up another'));
    await tester.pump();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('EGCM 10:00'), findsNothing);
  });
}
