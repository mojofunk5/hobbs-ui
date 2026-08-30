/// Mirrors the backend's AirfieldDto exactly - the shape returned by GET /airfield?search= (see
/// hobbs's AirfieldEndpoint). Airfield is reference data seeded from OurAirports' GB dataset, not
/// pilot-submitted - icaoCode/elevationFt are nullable since a handful of small strips in the
/// source data genuinely lack an ICAO code (see docs/plans/airfield-picker.md in the backend repo).
class Airfield {
  final String id;
  final String? icaoCode;
  final String name;
  final String municipality;
  final String isoCountry;
  final String isoRegion;
  final double latitude;
  final double longitude;
  final int? elevationFt;
  final String type;

  const Airfield({
    required this.id,
    this.icaoCode,
    required this.name,
    required this.municipality,
    required this.isoCountry,
    required this.isoRegion,
    required this.latitude,
    required this.longitude,
    this.elevationFt,
    required this.type,
  });

  factory Airfield.fromJson(Map<String, dynamic> json) => Airfield(
        id: json['id'] as String,
        icaoCode: json['icaoCode'] as String?,
        name: json['name'] as String,
        municipality: json['municipality'] as String,
        isoCountry: json['isoCountry'] as String,
        isoRegion: json['isoRegion'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        elevationFt: json['elevationFt'] as int?,
        type: json['type'] as String,
      );

  /// "EGCJ - Sherburn-in-Elmet Airfield", falling back to just the name when icaoCode is null (some
  /// small strips in the OurAirports GB dataset have no ICAO code at all).
  String get displayLabel => icaoCode == null ? name : '$icaoCode - $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Airfield && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
