import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/session.dart';
import 'api_base.dart';
import 'api_exception.dart';

/// Thin wrapper over hobbs's /auth/* endpoints. See AuthEndpoint/SessionDto in the backend for
/// the exact contract this mirrors.
class AuthApi {
  static Future<Session> register({
    required String name,
    required String email,
    required String password,
    required String referralCode,
    http.Client? client,
  }) =>
      _postForSession(
          '/auth/register',
          {
            'name': name,
            'email': email,
            'password': password,
            'referralCode': referralCode,
          },
          client);

  static Future<Session> login({
    required String identifier,
    required String password,
    http.Client? client,
  }) =>
      _postForSession('/auth/login',
          {'identifier': identifier, 'password': password}, client);

  static Future<Session> _postForSession(
    String path,
    Map<String, String> body,
    http.Client? client,
  ) async {
    final response = await (client ?? http.Client()).post(
      Uri.parse('$apiBase$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Session.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw ApiException(response.statusCode);
  }
}
