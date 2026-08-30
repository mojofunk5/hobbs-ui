import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pilot_summary.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's authenticated /pilot endpoints - see PilotEndpoint/PilotSummaryDto
/// in the backend for the exact contract this mirrors.
class PilotApi {
  /// Mirrors GET /pilot?search= - pilots known to the caller (themselves, anyone they created,
  /// anyone they've flown with as PIC or co-pilot), optionally filtered by a case-insensitive
  /// name substring. A null or empty [query] returns the caller's full known set - see
  /// docs/plans/pilot-picker.md in the backend repo.
  static Future<List<PilotSummary>> search({
    required String sessionId,
    String? query,
    http.Client? client,
  }) async {
    final uri = Uri.parse('$apiBase/pilot').replace(
      queryParameters:
          (query != null && query.isNotEmpty) ? {'search': query} : null,
    );
    final response = await (client ?? http.Client()).get(
      uri,
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List)
          .map((json) => PilotSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(response.statusCode);
  }

  /// Mirrors POST /pilot - creates an unclaimed pilot record owned by the caller (see
  /// PilotEndpoint.createPilot). Used by PilotPicker's inline "create new pilot" flow.
  static Future<PilotSummary> create({
    required String sessionId,
    required String name,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).post(
      Uri.parse('$apiBase/pilot'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionId',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return PilotSummary.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(response.statusCode);
  }
}
