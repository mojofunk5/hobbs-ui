import 'package:shared_preferences/shared_preferences.dart';

/// The login identifier remembered via the "Remember my email" checkbox - separate from
/// [SessionStore] since this is just a convenience for pre-filling the field, not an active
/// session. Saved/cleared only as part of a successful login submit (see LoginScreen), not on
/// every keystroke.
class RememberedIdentifier {
  static const _key = 'hobbs_remembered_identifier';

  static Future<void> save(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, identifier);
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
