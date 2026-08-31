import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flight_entry_context.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's authenticated GET /flight-entry-context - see
/// FlightEntryContextEndpoint/FlightEntryContextDto in the backend for the exact contract this
/// mirrors. One call that prefetches everything CreateFlightEntryScreen's pickers need, instead
/// of each picker fetching its own on-focus suggestions.
class FlightEntryContextApi {
  static Future<FlightEntryContext> fetch({
    required String sessionId,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).get(
      Uri.parse('$apiBase/flight-entry-context'),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return FlightEntryContext.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(response.statusCode);
  }
}
