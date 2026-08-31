import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/airfield.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's authenticated GET /airfield?search= - see AirfieldEndpoint/AirfieldDto
/// in the backend for the exact contract this mirrors. Like PilotApi.search (and unlike
/// AircraftApi's required 2-character minimum), search is optional here: against the ~1,200-row GB
/// seed set, an empty or missing search reasonably returns everything, ordered by the backend
/// (the calling pilot's recently-flown airfields first, then alphabetical) - this wrapper doesn't
/// re-rank the results itself.
class AirfieldApi {
  static Future<List<Airfield>> search({
    required String sessionId,
    String? query,
    http.Client? client,
  }) async {
    final uri = Uri.parse('$apiBase/airfield').replace(
      queryParameters:
          (query != null && query.isNotEmpty) ? {'search': query} : null,
    );
    final response = await (client ?? http.Client()).get(
      uri,
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List)
          .map((json) => Airfield.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(response.statusCode);
  }

  /// Thin wrapper over GET /airfield/recent - the calling pilot's own last 5 distinct flown
  /// airfields, most recently flown first. Right-sized for [AirfieldPicker]'s on-focus browse,
  /// versus [search] with no query which returns the full ~1,200-row reference table.
  static Future<List<Airfield>> recent({
    required String sessionId,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).get(
      Uri.parse('$apiBase/airfield/recent'),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List)
          .map((json) => Airfield.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(response.statusCode);
  }
}
