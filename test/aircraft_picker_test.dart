import 'dart:async';

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
    List<Aircraft>? initialSuggestions,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AircraftPicker(
          sessionId: 'session-1',
          label: 'Aircraft',
          httpClient: client,
          initialValue: initialValue,
          initialSuggestions: initialSuggestions,
          onChanged: onChanged,
        ),
      ),
    ));
  }

  testWidgets(
      'gaining focus loads the callers recently-flown aircraft as suggestions',
      (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/aircraft/recent'));
      return http.Response(
          '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
  });

  testWidgets(
      'clearing back to an empty field while focused reloads recent aircraft',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/aircraft/recent')) {
        return http.Response(
            '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200);
      }
      return http.Response('[]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
  });

  testWidgets(
      'does not search the typed-registration endpoint until at least 2 characters are typed',
      (tester) async {
    var searchRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/aircraft')) {
        searchRequests++;
      }
      return http.Response('[]', 200);
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'g');
    await tester.pump(const Duration(milliseconds: 350));

    expect(searchRequests, 0);
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
    // Not yet - still within the debounce window (the on-focus recent-items load fires
    // immediately, but the typed search for "ab" doesn't).
    expect(queries, isNot(contains('ab')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(queries, contains('ab'));
    expect(registrationOnlyValues, contains('true'));
    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
  });

  testWidgets(
      'shows the searching indicator from the keystroke, not just once the debounced search starts',
      (tester) async {
    final client = MockClient((request) async => http.Response(
        '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'ab');
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
      if (query == null) {
        // The on-focus recent-items load, irrelevant to this race - resolve it immediately.
        return http.Response('[]', 200);
      }
      return completers.putIfAbsent(query, Completer<http.Response>.new).future;
    });

    await pumpPicker(tester, client: client, onChanged: (_) {});

    // Two searches end up in flight at once - typing "g-sa", pausing long enough for its
    // debounced search to fire, then typing on to "g-sacr" and pausing again before the first
    // has responded (this is the exact sequence that produced stale results in practice).
    await tester.enterText(find.byType(TextField), 'g-sa');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'g-sacr');
    await tester.pump(const Duration(milliseconds: 350));

    // Resolve out of order: the later, more specific request ("g-sacr") finishes first; the
    // earlier, now-stale request ("g-sa") finishes after it. The stale response must not win.
    completers['g-sacr']!.complete(http.Response(
        '[{"id":"aircraft-1","registration":"G-SACR","make":"Cessna","model":"152"}]', 200));
    await tester.pump();
    completers['g-sa']!.complete(http.Response(
        '[{"id":"aircraft-2","registration":"G-SAAA"}]', 200));
    await tester.pump();

    expect(find.text('G-SACR - Cessna 152'), findsOneWidget);
    expect(find.text('G-SAAA'), findsNothing);
  });

  testWidgets('shows a no-matches message when the search returns nothing',
      (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));

    await pumpPicker(tester, client: client, onChanged: (_) {});
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('No aircraft found - check the registration and try again'),
        findsOneWidget);
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
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('tapping the clear icon removes the selection and refocuses',
      (tester) async {
    Aircraft? selected;
    final client = MockClient((request) async => http.Response(
        '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200));

    await pumpPicker(tester, client: client, onChanged: (a) => selected = a);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('G-ABCD - Cessna 152'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(selected, isNull);
    expect(find.widgetWithText(TextField, 'G-ABCD - Cessna 152'), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets(
      'gaining focus with initialSuggestions set shows them immediately with no HTTP call',
      (tester) async {
    var requestMade = false;
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response('[]', 200);
    });
    const cessna = Aircraft(id: 'aircraft-1', registration: 'G-ABCD', make: 'Cessna', model: '152');

    await pumpPicker(tester,
        client: client, onChanged: (_) {}, initialSuggestions: [cessna]);
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text('G-ABCD - Cessna 152'), findsOneWidget);
    expect(requestMade, isFalse);
  });

  testWidgets(
      'clearing a selection still hits the network even with initialSuggestions set',
      (tester) async {
    var requestMade = false;
    const cessna = Aircraft(id: 'aircraft-1', registration: 'G-ABCD', make: 'Cessna', model: '152');
    final client = MockClient((request) async {
      requestMade = true;
      return http.Response(
          '[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna","model":"152"}]', 200);
    });

    await pumpPicker(tester,
        client: client,
        onChanged: (_) {},
        initialValue: cessna,
        initialSuggestions: [cessna]);
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();

    expect(requestMade, isTrue);
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
