import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flight_entry.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's authenticated /flight endpoints. See FlightEntryEndpoint/
/// FlightEntryDto/CreateFlightEntryDto in the backend for the exact contract this mirrors.
class FlightApi {
  static Future<FlightEntry> createFlightEntry({
    required String sessionId,
    required String aircraftId,
    String? flightTrackId,
    required DateTime date,
    required DateTime departureTime,
    required DateTime arrivalTime,
    required String departureAirfieldId,
    required String arrivalAirfieldId,
    required String pilotInCommandId,
    String? coPilotId,
    required int singleEngineMinutes,
    required int multiEngineMinutes,
    required int totalMinutes,
    required int nightMinutes,
    required int ifrMinutes,
    required int crossCountryMinutes,
    required int pilotInCommandMinutes,
    required int coPilotMinutes,
    required int dualMinutes,
    required int instructorMinutes,
    required int dayLandings,
    required int nightLandings,
    String? remarks,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).post(
      Uri.parse('$apiBase/flight'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionId',
      },
      body: jsonEncode({
        'aircraftId': aircraftId,
        'flightTrackId': flightTrackId,
        'date': _dateOnly(date),
        'departureTime': departureTime.toUtc().toIso8601String(),
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
        'departureAirfieldId': departureAirfieldId,
        'arrivalAirfieldId': arrivalAirfieldId,
        'pilotInCommandId': pilotInCommandId,
        'coPilotId': coPilotId,
        'singleEngineMinutes': singleEngineMinutes,
        'multiEngineMinutes': multiEngineMinutes,
        'totalMinutes': totalMinutes,
        'nightMinutes': nightMinutes,
        'ifrMinutes': ifrMinutes,
        'crossCountryMinutes': crossCountryMinutes,
        'pilotInCommandMinutes': pilotInCommandMinutes,
        'coPilotMinutes': coPilotMinutes,
        'dualMinutes': dualMinutes,
        'instructorMinutes': instructorMinutes,
        'dayLandings': dayLandings,
        'nightLandings': nightLandings,
        'remarks': remarks,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return FlightEntry.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(response.statusCode);
  }

  /// Mirrors GET /flight/{flightEntryId} - 403s if the entry belongs to a different pilot, 404s
  /// if no such entry exists (see FlightEntryEndpoint.getFlightEntry).
  static Future<FlightEntry> getFlightEntry({
    required String sessionId,
    required String flightEntryId,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).get(
      Uri.parse('$apiBase/flight/$flightEntryId'),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return FlightEntry.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(response.statusCode);
  }

  /// Mirrors GET /flight - every entry for the authenticated pilot, already sorted newest-first
  /// by date then departure time (see FlightEntryRepository.findAllByPilotId). No pagination yet
  /// (see CLAUDE.md's "Not yet built" note) - returns everything in one response.
  static Future<List<FlightEntry>> listFlightEntries({
    required String sessionId,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client()).get(
      Uri.parse('$apiBase/flight'),
      headers: {'Authorization': 'Bearer $sessionId'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (jsonDecode(response.body) as List)
          .map((json) => FlightEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(response.statusCode);
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
