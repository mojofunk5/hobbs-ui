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
    required String departurePlace,
    required DateTime departureTime,
    required String arrivalPlace,
    required DateTime arrivalTime,
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
        'departurePlace': departurePlace,
        'departureTime': departureTime.toUtc().toIso8601String(),
        'arrivalPlace': arrivalPlace,
        'arrivalTime': arrivalTime.toUtc().toIso8601String(),
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

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
