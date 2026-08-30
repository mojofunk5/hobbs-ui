import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/aircraft_api.dart';
import '../models/aircraft.dart';
import '../models/session.dart';
import '../widgets/aircraft_picker.dart';
import '../widgets/responsive_page.dart';

/// Browses the aircraft reference data seeded from OpenSky (see docs/plans/aircraft-picker.md) -
/// search-first, same "must search" shape as [AircraftPicker] and for the same reason: the
/// backend's GET /aircraft?search= requires at least [AircraftPicker.minSearchLength] characters
/// rather than defaulting to "everything" (~600k rows once the full import runs), so this is never
/// a paginated list-everything screen. Shows the full reference-data field set (owner, built,
/// engines, operator, serial number) that the picker itself doesn't render.
class BrowseAircraftScreen extends StatefulWidget {
  const BrowseAircraftScreen({super.key, required this.session, this.httpClient});

  final Session session;

  /// Overridable for tests - see test/browse_aircraft_screen_test.dart.
  final http.Client? httpClient;

  @override
  State<BrowseAircraftScreen> createState() => _BrowseAircraftScreenState();
}

class _BrowseAircraftScreenState extends State<BrowseAircraftScreen> {
  static const _debounceDelay = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  List<Aircraft> _results = [];
  bool _searching = false;
  bool _searched = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < AircraftPicker.minSearchLength) {
      setState(() {
        _results = [];
        _searching = false;
        _searched = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(_debounceDelay, () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await AircraftApi.search(
        sessionId: widget.session.sessionId,
        query: query,
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
        _searched = true;
        _error = 'Could not search aircraft.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse aircraft')),
      body: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Search registration, make or model',
                helperText:
                    'Type at least ${AircraftPicker.minSearchLength} characters',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onTextChanged,
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!),
            if (_searched && !_searching && _results.isEmpty && _error == null)
              const Text('No aircraft matched.'),
            for (final aircraft in _results) _AircraftTile(aircraft: aircraft),
          ],
        ),
      ),
    );
  }
}

class _AircraftTile extends StatelessWidget {
  const _AircraftTile({required this.aircraft});

  final Aircraft aircraft;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (aircraft.owner != null) 'Owner: ${aircraft.owner}',
      if (aircraft.operator != null) 'Operator: ${aircraft.operator}',
      if (aircraft.built != null) 'Built: ${aircraft.built}',
      if (aircraft.engines != null) 'Engines: ${aircraft.engines}',
      if (aircraft.serialNumber != null) 'Serial: ${aircraft.serialNumber}',
    ];
    return Card(
      child: ListTile(
        title: Text(aircraft.displayLabel),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      ),
    );
  }
}
