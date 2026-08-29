import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/session.dart';

/// Persists the current session so a page reload doesn't sign the pilot out. Backed by
/// shared_preferences (localStorage on web) rather than an in-memory field precisely so it
/// survives that reload - the whole point of storing it at all.
class SessionStore {
  static const _key = 'hobbs_session';

  static Future<void> save(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(session.toJson()));
  }

  static Future<Session?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return Session.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
