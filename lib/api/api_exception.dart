/// Thrown for any non-2xx response from the backend. hobbs's auth endpoints never return a
/// parseable JSON error body on failure (Javalin's exception handlers set only a status code,
/// occasionally plain text) - so callers branch on [statusCode], not a parsed error shape.
class ApiException implements Exception {
  final int statusCode;

  const ApiException(this.statusCode);

  @override
  String toString() => 'ApiException(statusCode: $statusCode)';
}
