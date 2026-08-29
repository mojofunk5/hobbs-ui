import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/flight_api.dart';
import '../format.dart';
import '../models/flight_entry.dart';
import '../models/session.dart';
import '../widgets/responsive_page.dart';
import 'view_flight_entry_screen.dart';

/// Lists every flight entry for the authenticated pilot - see docs/plans/logbook-entries.md
/// (chunk 4) in the hobbs repo. Each row navigates to ViewFlightEntryScreen (chunk 3) by id. No
/// pagination/filtering yet - mirrors GET /flight, which returns everything in one response.
class ListFlightEntriesScreen extends StatefulWidget {
  const ListFlightEntriesScreen(
      {super.key, required this.session, this.httpClient});

  final Session session;

  /// Overridable for tests - see test/list_flight_entries_screen_test.dart.
  final http.Client? httpClient;

  @override
  State<ListFlightEntriesScreen> createState() =>
      _ListFlightEntriesScreenState();
}

class _ListFlightEntriesScreenState extends State<ListFlightEntriesScreen> {
  bool _loading = true;
  String? _error;
  List<FlightEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await FlightApi.listFlightEntries(
        sessionId: widget.session.sessionId,
        client: widget.httpClient,
      );
      setState(() => _entries = entries);
    } on ApiException catch (e) {
      setState(() =>
          _error = 'Could not load flight entries (HTTP ${e.statusCode}).');
    } catch (e) {
      setState(() => _error = 'Could not reach the backend: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEntry(FlightEntry entry) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ViewFlightEntryScreen(
              session: widget.session,
              initialFlightEntryId: entry.id,
              httpClient: widget.httpClient,
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your flights')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _entries.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ResponsivePage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return ListView(
        // A ListView (not a plain Center) so pull-to-refresh still works with nothing in it -
        // RefreshIndicator needs a scrollable descendant to attach its gesture to.
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No flights logged yet.')),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          title: Text('${entry.departurePlace} → ${entry.arrivalPlace}'),
          subtitle: Text(formatDate(entry.date)),
          trailing: Text(formatMinutes(entry.totalMinutes)),
          onTap: () => _openEntry(entry),
        );
      },
    );
  }
}
