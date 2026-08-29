import 'package:flutter/material.dart';

import '../models/session.dart';
import '../session_store.dart';
import 'health_check_screen.dart';
import 'signed_in_screen.dart';

/// Decides the app's initial screen: straight to [SignedInScreen] if a session was already
/// persisted (survives a page reload), otherwise the health-check screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  Session? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SessionStore.load().then((session) {
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _session != null
        ? SignedInScreen(session: _session!)
        : const HealthCheckPage();
  }
}
