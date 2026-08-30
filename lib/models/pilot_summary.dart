/// Mirrors the backend's PilotSummaryDto exactly - the shape returned by both
/// GET /pilot?search= and POST /pilot (see hobbs's PilotEndpoint).
class PilotSummary {
  final String id;
  final String name;

  const PilotSummary({required this.id, required this.name});

  factory PilotSummary.fromJson(Map<String, dynamic> json) => PilotSummary(
        id: json['id'] as String,
        name: json['name'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PilotSummary && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
