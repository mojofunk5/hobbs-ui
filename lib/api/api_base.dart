// Empty by default so a production build (served behind Caddy, which proxies /api/* to the
// backend) hits a same-origin relative path. Local dev overrides it to the backend's own origin:
// flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: '/api');
