import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/flight_api.dart';
import '../format.dart';
import '../models/flight_entry.dart';
import '../models/session.dart';
import '../widgets/responsive_page.dart';

/// Looks up a single flight entry by id - see docs/plans/logbook-entries.md (chunk 3) in the
/// hobbs repo. Reachable by pasting/typing a known entry id directly, per that plan's "no users
/// yet" note: there's no list to navigate in from until chunk 4.
class ViewFlightEntryScreen extends StatefulWidget {
  const ViewFlightEntryScreen(
      {super.key,
      required this.session,
      this.initialFlightEntryId,
      this.httpClient});

  final Session session;

  /// Pre-fills and immediately looks up an id - used when jumping straight here after creating
  /// an entry (see CreateFlightEntryScreen's "View it" button).
  final String? initialFlightEntryId;

  /// Overridable for tests - see test/view_flight_entry_screen_test.dart.
  final http.Client? httpClient;

  @override
  State<ViewFlightEntryScreen> createState() => _ViewFlightEntryScreenState();
}

class _ViewFlightEntryScreenState extends State<ViewFlightEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _flightEntryIdController =
      TextEditingController(text: widget.initialFlightEntryId);

  bool _loading = false;
  String? _error;
  FlightEntry? _entry;

  @override
  void initState() {
    super.initState();
    if (widget.initialFlightEntryId != null &&
        widget.initialFlightEntryId!.isNotEmpty) {
      _lookUp();
    }
  }

  @override
  void dispose() {
    _flightEntryIdController.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry = await FlightApi.getFlightEntry(
        sessionId: widget.session.sessionId,
        flightEntryId: _flightEntryIdController.text.trim(),
        client: widget.httpClient,
      );
      setState(() => _entry = entry);
    } on ApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          403 => 'That entry belongs to a different pilot.',
          404 => 'No entry found with that id.',
          _ => 'Could not fetch the entry (HTTP ${e.statusCode}).',
        };
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the backend: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _lookUpAnother() {
    setState(() {
      _entry = null;
      _error = null;
      _flightEntryIdController.clear();
    });
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      appBar: AppBar(title: const Text('View a flight')),
      body: ResponsivePage(
        child: entry == null
            ? Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _flightEntryIdController,
                      decoration: const InputDecoration(labelText: 'Entry id'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _loading ? null : _lookUp,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('View'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _row('Date', formatDate(entry.date)),
                    _row('Aircraft', entry.aircraftId),
                    _row('Departure',
                        '${entry.departurePlace} ${formatTime(entry.departureTime)}'),
                    _row('Arrival',
                        '${entry.arrivalPlace} ${formatTime(entry.arrivalTime)}'),
                    _row('Pilot in command', entry.pilotInCommandId),
                    if (entry.coPilotId != null)
                      _row('Co-pilot', entry.coPilotId!),
                    const Divider(height: 24),
                    _row('Total', formatMinutes(entry.totalMinutes)),
                    _row('Single-engine',
                        formatMinutes(entry.singleEngineMinutes)),
                    _row('Multi-engine',
                        formatMinutes(entry.multiEngineMinutes)),
                    _row('Night', formatMinutes(entry.nightMinutes)),
                    _row('IFR', formatMinutes(entry.ifrMinutes)),
                    _row('Cross-country',
                        formatMinutes(entry.crossCountryMinutes)),
                    _row('PIC', formatMinutes(entry.pilotInCommandMinutes)),
                    _row('Co-pilot time', formatMinutes(entry.coPilotMinutes)),
                    _row('Dual', formatMinutes(entry.dualMinutes)),
                    _row('Instructor', formatMinutes(entry.instructorMinutes)),
                    const Divider(height: 24),
                    _row('Day landings', '${entry.dayLandings}'),
                    _row('Night landings', '${entry.nightLandings}'),
                    if (entry.remarks != null && entry.remarks!.isNotEmpty)
                      _row('Remarks', entry.remarks!),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: _lookUpAnother,
                      child: const Text('Look up another'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
