import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'screens/reset_password_screen.dart';
import 'screens/startup_screen.dart';

void main() {
  // Real paths (hobbs.bssd.co.uk/reset-password) instead of the default #/ hash URLs - the
  // backend's actual reset email links to a real path, and hash URLs wouldn't match it.
  usePathUrlStrategy();
  runApp(const HobbsApp());
}

class HobbsApp extends StatelessWidget {
  const HobbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Checked once at startup, not on every rebuild - Uri.base reflects the URL the app was
    // *loaded* with. Once a click-based reset flow completes, later navigation stays in-app and
    // doesn't touch the browser's address bar (this app doesn't use named routes/GoRouter for
    // that in-app navigation), so re-checking on rebuild would have nothing new to find anyway.
    final uri = Uri.base;
    final email = uri.queryParameters['email'];
    final code = uri.queryParameters['code'];
    final isResetLink =
        uri.path == '/reset-password' && email != null && code != null;

    return MaterialApp(
      title: 'Hobbs',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: isResetLink
          ? ResetPasswordScreen(initialEmail: email, initialCode: code)
          : const StartupScreen(),
    );
  }
}
