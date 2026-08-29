import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/session.dart';
import 'package:hobbs_ui/screens/create_flight_entry_screen.dart';

void main() {
  const session = Session(
    sessionId: 'session-1',
    pilotId: 'pilot-1',
    name: 'William',
    admin: false,
  );

  Future<void> pumpScreen(WidgetTester tester, {http.Client? client}) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateFlightEntryScreen(session: session, httpClient: client),
    ));
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'aircraft-1');
    await tester.enterText(find.byType(TextFormField).at(1), 'EGCM');
    await tester.enterText(find.byType(TextFormField).at(2), 'EGCC');
    await tester.enterText(find.byType(TextFormField).at(3), 'pilot-2');
    await tester.enterText(find.byType(TextFormField).at(5), '45');
  }

  testWidgets('does not submit when required fields are empty', (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response('', 200);
    });

    await pumpScreen(tester, client: client);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(requestMade, isFalse);
  });

  testWidgets('submitting the form saves the entry and shows its id',
      (tester) async {
    final client = MockClient((request) async {
      return http.Response(
          '{'
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
          '"singleEngineMinutes":0,'
          '"multiEngineMinutes":0,'
          '"totalMinutes":45,'
          '"nightMinutes":0,'
          '"ifrMinutes":0,'
          '"crossCountryMinutes":0,'
          '"pilotInCommandMinutes":0,'
          '"coPilotMinutes":0,'
          '"dualMinutes":0,'
          '"instructorMinutes":0,'
          '"dayLandings":1,'
          '"nightLandings":0,'
          '"remarks":null'
          '}',
          200);
    });

    await pumpScreen(tester, client: client);
    await fillRequiredFields(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pump();

    expect(find.text('Flight entry saved.'), findsOneWidget);
    expect(find.text('Entry id: entry-1'), findsOneWidget);
  });

  testWidgets('shows an error on a 400 response', (tester) async {
    final client = MockClient((request) async => http.Response('', 400));

    await pumpScreen(tester, client: client);
    await fillRequiredFields(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pump();

    expect(find.text('Check the entered fields - one or more is invalid.'),
        findsOneWidget);
  });
}
