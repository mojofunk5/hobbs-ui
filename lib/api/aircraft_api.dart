import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/aircraft.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's authenticated GET /aircraft?search= - see AircraftEndpoint/AircraftDto
/// in the backend for the exact contract this mirrors. Unlike PilotApi.search, there is no create
/// - aircraft is reference data (seeded from OpenSky), not pilot-submitted, and the backend itself
/// requires a non-empty search (minimum 2 characters, 400 otherwise) rather than defaulting to
/// "everything". This wrapper doesn't re-validate that - callers (AircraftPicker/BrowseAircraftScreen)
/// are responsible for not calling it below that length.
class AircraftApi {
  /// [registrationOnly] mirrors the backend's own query param - AircraftPicker (flight-entry
  /// form) passes true, since a pilot who already knows the tail number doesn't want incidental
  /// hits on a make/model substring; BrowseAircraftScreen leaves it false for its broader
  /// discovery search.
  static Future<List<Aircraft>> search({
    required String sessionId,
    required String query,
    bool registrationOnly = false,
    http.Client? client,
  }) async {
    final uri = Uri.parse('$apiBase/aircraft').replace(queryParameters: {
      'search': query,
      if (registrationOnly) 'registrationOnly': 'true',
    });
    final response = await (client ?? http.Client()).get(
      uri,
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List)
          .map((json) => Aircraft.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(response.statusCode);
  }
}
