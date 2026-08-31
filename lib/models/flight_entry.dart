/// Mirrors the backend's FlightEntryDto exactly - see hobbs's FlightEntryDto/FlightEntryEndpoint
/// for the exact contract this mirrors. `id` is server-generated, so it's absent from the create
/// request (see FlightApi.createFlightEntry) but always present here on the response.
class FlightEntry {
  final String id;
  final String aircraftId;
  final String? flightTrackId;
  final DateTime date;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final String departureAirfieldId;
  final String arrivalAirfieldId;
  final String pilotInCommandId;
  final String? coPilotId;

  /// The raw enum value (e.g. "PILOT_UNDER_TRAINING") - see HolderOperatingCapacityField for the
  /// picker that produces this on create. [holderOperatingCapacityNotation] is the CAA shorthand
  /// (e.g. "P.u/t") derived server-side from this same value - never re-derive it client-side, per
  /// hobbs's docs/plans/holder-operating-capacity.md.
  final String holderOperatingCapacity;
  final String holderOperatingCapacityNotation;
  final int singleEngineMinutes;
  final int multiEngineMinutes;
  final int totalMinutes;
  final int nightMinutes;
  final int ifrMinutes;
  final int crossCountryMinutes;
  final int pilotInCommandMinutes;
  final int coPilotMinutes;
  final int dualMinutes;
  final int instructorMinutes;
  final int dayLandings;
  final int nightLandings;
  final String? remarks;

  const FlightEntry({
    required this.id,
    required this.aircraftId,
    this.flightTrackId,
    required this.date,
    required this.departureTime,
    required this.arrivalTime,
    required this.departureAirfieldId,
    required this.arrivalAirfieldId,
    required this.pilotInCommandId,
    this.coPilotId,
    required this.holderOperatingCapacity,
    required this.holderOperatingCapacityNotation,
    required this.singleEngineMinutes,
    required this.multiEngineMinutes,
    required this.totalMinutes,
    required this.nightMinutes,
    required this.ifrMinutes,
    required this.crossCountryMinutes,
    required this.pilotInCommandMinutes,
    required this.coPilotMinutes,
    required this.dualMinutes,
    required this.instructorMinutes,
    required this.dayLandings,
    required this.nightLandings,
    this.remarks,
  });

  factory FlightEntry.fromJson(Map<String, dynamic> json) => FlightEntry(
        id: json['id'] as String,
        aircraftId: json['aircraftId'] as String,
        flightTrackId: json['flightTrackId'] as String?,
        date: DateTime.parse(json['date'] as String),
        departureTime: DateTime.parse(json['departureTime'] as String),
        arrivalTime: DateTime.parse(json['arrivalTime'] as String),
        departureAirfieldId: json['departureAirfieldId'] as String,
        arrivalAirfieldId: json['arrivalAirfieldId'] as String,
        pilotInCommandId: json['pilotInCommandId'] as String,
        coPilotId: json['coPilotId'] as String?,
        holderOperatingCapacity: json['holderOperatingCapacity'] as String,
        holderOperatingCapacityNotation:
            json['holderOperatingCapacityNotation'] as String,
        singleEngineMinutes: json['singleEngineMinutes'] as int,
        multiEngineMinutes: json['multiEngineMinutes'] as int,
        totalMinutes: json['totalMinutes'] as int,
        nightMinutes: json['nightMinutes'] as int,
        ifrMinutes: json['ifrMinutes'] as int,
        crossCountryMinutes: json['crossCountryMinutes'] as int,
        pilotInCommandMinutes: json['pilotInCommandMinutes'] as int,
        coPilotMinutes: json['coPilotMinutes'] as int,
        dualMinutes: json['dualMinutes'] as int,
        instructorMinutes: json['instructorMinutes'] as int,
        dayLandings: json['dayLandings'] as int,
        nightLandings: json['nightLandings'] as int,
        remarks: json['remarks'] as String?,
      );
}
