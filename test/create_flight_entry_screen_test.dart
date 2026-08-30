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

  // The PilotPicker fields (PIC/co-pilot) issue GET /pilot?search= calls of their own (an initial
  // one on focus, plus one per debounced keystroke), AircraftPicker issues GET /aircraft?search=,
  // and the two AirfieldPicker fields issue GET /airfield?search= (also on-focus, like PilotPicker)
  // - route all three to canned results so they don't interfere with assertions about the
  // FlightApi.createFlightEntry request itself.
  http.Client wrapClient(
      Future<http.Response> Function(http.Request) onCreateFlightEntry) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/pilot')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/aircraft')) {
        return http.Response(
            '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]',
            200);
      }
      if (request.url.path.endsWith('/airfield')) {
        return http.Response(
            '[{"id":"airfield-1","icaoCode":"EGCM","name":"Manchester Barton Aerodrome",'
            '"municipality":"Manchester","isoCountry":"GB","isoRegion":"GB-ENG",'
            '"latitude":53.47,"longitude":-2.38,"elevationFt":80,"type":"small_airport"},'
            '{"id":"airfield-2","icaoCode":"EGCC","name":"Manchester Airport",'
            '"municipality":"Manchester","isoCountry":"GB","isoRegion":"GB-ENG",'
            '"latitude":53.35,"longitude":-2.27,"elevationFt":257,"type":"large_airport"}]',
            200);
      }
      return onCreateFlightEntry(request);
    });
  }

  Future<void> pumpScreen(WidgetTester tester, {http.Client? client}) async {
    await tester.pumpWidget(MaterialApp(
      home: CreateFlightEntryScreen(session: session, httpClient: client),
    ));
  }

  Future<void> pickAircraft(WidgetTester tester) async {
    final field = find.descendant(
        of: find.byKey(const Key('aircraftPicker')), matching: find.byType(TextField));
    await tester.enterText(field, 'G-ABCD');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('G-ABCD - Cessna 152'));
    await tester.pump();
  }

  Future<void> pickAirfield(WidgetTester tester, Key pickerKey, String label) async {
    final field = find.descendant(
        of: find.byKey(pickerKey), matching: find.byType(TextField));
    await tester.tap(field);
    await tester.pump();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    await pickAircraft(tester);
    await pickAirfield(tester, const Key('departureAirfieldPicker'),
        'EGCM - Manchester Barton Aerodrome');
    await pickAirfield(
        tester, const Key('arrivalAirfieldPicker'), 'EGCC - Manchester Airport');
    // Pilot in command defaults to the caller (William) - already set, nothing to fill in here.
    await tester.enterText(find.byType(TextFormField).first, '45');
  }

  testWidgets('does not submit when required fields are empty', (tester) async {
    var requestMade = false;
    final client = wrapClient((request) async {
      requestMade = true;
      return http.Response('', 200);
    });

    await pumpScreen(tester, client: client);
    // Clear the PIC default so the "Required" path is exercised too. Flushes the picker's
    // focus-triggered search and its debounced re-search after the text change, so no Timer is
    // left pending when the test ends.
    await tester.enterText(
        find.descendant(
            of: find.byKey(const Key('pilotInCommandPicker')),
            matching: find.byType(TextField)),
        '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(requestMade, isFalse);
  });

  testWidgets('pilot in command defaults to the caller themselves',
      (tester) async {
    await pumpScreen(tester, client: wrapClient((_) async => http.Response('', 200)));

    expect(find.text('William'), findsOneWidget);
  });

  testWidgets('submitting the form saves the entry and shows its id',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pilot')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/aircraft')) {
        return http.Response(
            '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]',
            200);
      }
      if (request.url.path.endsWith('/airfield')) {
        return http.Response(
            '[{"id":"airfield-1","icaoCode":"EGCM","name":"Manchester Barton Aerodrome",'
            '"municipality":"Manchester","isoCountry":"GB","isoRegion":"GB-ENG",'
            '"latitude":53.47,"longitude":-2.38,"elevationFt":80,"type":"small_airport"},'
            '{"id":"airfield-2","icaoCode":"EGCC","name":"Manchester Airport",'
            '"municipality":"Manchester","isoCountry":"GB","isoRegion":"GB-ENG",'
            '"latitude":53.35,"longitude":-2.27,"elevationFt":257,"type":"large_airport"}]',
            200);
      }
      return http.Response(
          '{'
          '"id":"entry-1",'
          '"aircraftId":"aircraft-1",'
          '"flightTrackId":null,'
          '"date":"2026-08-24",'
          '"departureTime":"2026-08-24T10:00:00Z",'
          '"arrivalTime":"2026-08-24T10:45:00Z",'
          '"departureAirfieldId":"airfield-1",'
          '"arrivalAirfieldId":"airfield-2",'
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
    final client = wrapClient((request) async => http.Response('', 400));

    await pumpScreen(tester, client: client);
    await fillRequiredFields(tester);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save entry'));
    await tester.pump();

    expect(find.text('Check the entered fields - one or more is invalid.'),
        findsOneWidget);
  });
}
