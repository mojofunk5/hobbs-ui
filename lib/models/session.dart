/// Mirrors the backend's SessionDto exactly - see hobbs's AuthEndpoint/SessionDto.
class Session {
  final String sessionId;
  final String pilotId;
  final String name;
  final bool admin;

  const Session({
    required this.sessionId,
    required this.pilotId,
    required this.name,
    required this.admin,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        sessionId: json['sessionId'] as String,
        pilotId: json['pilotId'] as String,
        name: json['name'] as String,
        admin: json['admin'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'pilotId': pilotId,
        'name': name,
        'admin': admin,
      };
}
