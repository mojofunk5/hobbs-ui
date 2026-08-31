import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hobbs_ui/api/api_exception.dart';
import 'package:hobbs_ui/api/flight_entry_context_api.dart';

void main() {
  test('fetch parses the aggregated response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/flight-entry-context'));
      expect(request.headers['Authorization'], 'Bearer session-1');
      return http.Response(
          '{'
          '"recentAirfields":[{"id":"airfield-1","icaoCode":"EGCJ",'
          '"name":"Sherburn-in-Elmet Airfield","municipality":"Sherburn-in-Elmet",'
          '"isoCountry":"GB","isoRegion":"GB-ENG","latitude":53.79,"longitude":-1.23,'
          '"elevationFt":20,"type":"small_airport"}],'
          '"recentAircraft":[{"id":"aircraft-1","registration":"G-ABCD","make":"Cessna",'
          '"model":"152"}],'
          '"knownPilots":[{"id":"pilot-1","name":"William"}]'
          '}',
          200);
    });

    final result = await FlightEntryContextApi.fetch(
        sessionId: 'session-1', client: client);

    expect(result.recentAirfields, hasLength(1));
    expect(result.recentAirfields.first.icaoCode, 'EGCJ');
    expect(result.recentAircraft, hasLength(1));
    expect(result.recentAircraft.first.registration, 'G-ABCD');
    expect(result.knownPilots, hasLength(1));
    expect(result.knownPilots.first.name, 'William');
  });

  test('throws ApiException on a non-2xx response', () async {
    final client = MockClient((request) async => http.Response('', 500));

    expect(
      () => FlightEntryContextApi.fetch(sessionId: 'session-1', client: client),
      throwsA(isA<ApiException>()),
    );
  });
}
