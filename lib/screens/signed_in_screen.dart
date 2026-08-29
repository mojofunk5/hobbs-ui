import 'package:flutter/material.dart';

import '../models/session.dart';
import '../session_store.dart';
import '../widgets/responsive_page.dart';
import 'create_flight_entry_screen.dart';
import 'view_flight_entry_screen.dart';
import 'welcome_screen.dart';

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({super.key, required this.session});

  final Session session;

  Future<void> _logOut(BuildContext context) async {
    await SessionStore.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hobbs')),
      body: ResponsivePage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_takeoff, size: 64, color: Colors.indigo),
            const SizedBox(height: 16),
            Text('Signed in as ${session.name}',
                style: Theme.of(context).textTheme.headlineSmall),
            if (session.admin) ...[
              const SizedBox(height: 8),
              const Chip(label: Text('Admin')),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CreateFlightEntryScreen(session: session))),
              child: const Text('Log a flight'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ViewFlightEntryScreen(session: session))),
              child: const Text('View a flight'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: () => _logOut(context),
                child: const Text('Log out')),
          ],
        ),
      ),
    );
  }
}
