import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/models/session.dart';
import 'package:hobbs_ui/screens/browse_aircraft_screen.dart';

void main() {
  const session = Session(
    sessionId: 'session-1',
    pilotId: 'pilot-1',
    name: 'William',
    admin: false,
  );

  Future<void> pumpScreen(WidgetTester tester, {required http.Client client}) async {
    await tester.pumpWidget(MaterialApp(
      home: BrowseAircraftScreen(session: session, httpClient: client),
    ));
  }

  testWidgets('does not search until at least 2 characters are typed',
      (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('[]', 200);
    });

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextField), 'g');
    await tester.pump(const Duration(milliseconds: 350));

    expect(requests, 0);
  });

  testWidgets('shows full reference-data fields for a matched aircraft',
      (tester) async {
    final client = MockClient((request) async => http.Response(
        '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152",'
        '"owner":"Acme Ltd","operator":"Acme Flying Club","built":1978,'
        '"engines":"1 Lycoming O-235","serialNumber":"15280001"}]',
        200));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextField), 'abcd');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
    expect(
        find.text('Owner: Acme Ltd · Operator: Acme Flying Club · Built: 1978 · '
            'Engines: 1 Lycoming O-235 · Serial: 15280001'),
        findsOneWidget);
  });

  testWidgets('shows a no-matches message when the search returns nothing',
      (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpScreen(tester, client: client);
    await tester.enterText(find.byType(TextField), 'nomatch');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No aircraft matched.'), findsOneWidget);
  });
}
