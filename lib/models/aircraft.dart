/// Mirrors the backend's AircraftDto - the shape returned by GET /aircraft?search= (see hobbs's
/// AircraftEndpoint). Aircraft is reference data seeded from OpenSky, not pilot-submitted - every
/// field but id/registration is nullable, since a CSV row (or a row created before this plan) may
/// not have it. Reused by both AircraftPicker (which only shows registration/make/model) and
/// BrowseAircraftScreen (which shows everything).
class Aircraft {
  final String id;
  final String registration;
  final String? make;
  final String? model;
  final String? engineCategory;
  final String? manufacturerIcao;
  final String? typeCode;
  final String? serialNumber;
  final String? operator;
  final String? owner;
  final int? built;
  final String? engines;
  final String? categoryDescription;

  const Aircraft({
    required this.id,
    required this.registration,
    this.make,
    this.model,
    this.engineCategory,
    this.manufacturerIcao,
    this.typeCode,
    this.serialNumber,
    this.operator,
    this.owner,
    this.built,
    this.engines,
    this.categoryDescription,
  });

  factory Aircraft.fromJson(Map<String, dynamic> json) => Aircraft(
        id: json['id'] as String,
        registration: json['registration'] as String,
        make: json['make'] as String?,
        model: json['model'] as String?,
        engineCategory: json['engineCategory'] as String?,
        manufacturerIcao: json['manufacturerIcao'] as String?,
        typeCode: json['typeCode'] as String?,
        serialNumber: json['serialNumber'] as String?,
        operator: json['operator'] as String?,
        owner: json['owner'] as String?,
        built: json['built'] as int?,
        engines: json['engines'] as String?,
        categoryDescription: json['categoryDescription'] as String?,
      );

  /// "G-ABCD - Cessna 152" (falling back gracefully when make/model are missing).
  String get displayLabel {
    final makeModel = [make, model].whereType<String>().join(' ');
    return makeModel.isEmpty ? registration : '$registration - $makeModel';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Aircraft && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
