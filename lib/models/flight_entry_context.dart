import 'aircraft.dart';
import 'airfield.dart';
import 'pilot_summary.dart';

/// Mirrors the backend's FlightEntryContextDto exactly - the shape returned by
/// GET /flight-entry-context (see hobbs's FlightEntryContextEndpoint), aggregating
/// GET /airfield/recent, GET /aircraft/recent, and GET /pilot?search= (no query) into one
/// response for CreateFlightEntryScreen's pickers to prefetch in a single round trip.
class FlightEntryContext {
  final List<Airfield> recentAirfields;
  final List<Aircraft> recentAircraft;
  final List<PilotSummary> knownPilots;

  const FlightEntryContext({
    required this.recentAirfields,
    required this.recentAircraft,
    required this.knownPilots,
  });

  factory FlightEntryContext.fromJson(Map<String, dynamic> json) =>
      FlightEntryContext(
        recentAirfields: (json['recentAirfields'] as List)
            .map((e) => Airfield.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentAircraft: (json['recentAircraft'] as List)
            .map((e) => Aircraft.fromJson(e as Map<String, dynamic>))
            .toList(),
        knownPilots: (json['knownPilots'] as List)
            .map((e) => PilotSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
