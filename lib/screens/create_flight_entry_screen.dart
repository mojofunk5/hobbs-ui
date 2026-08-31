import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/flight_api.dart';
import '../api/flight_entry_context_api.dart';
import '../format.dart';
import '../models/aircraft.dart';
import '../models/airfield.dart';
import '../models/flight_entry.dart';
import '../models/flight_entry_context.dart';
import '../models/pilot_summary.dart';
import '../models/session.dart';
import '../widgets/aircraft_picker.dart';
import '../widgets/airfield_picker.dart';
import '../widgets/holder_operating_capacity_field.dart';
import '../widgets/pilot_picker.dart';
import '../widgets/responsive_page.dart';
import 'view_flight_entry_screen.dart';

/// The CAP804/FCL.050 logbook entry form - see docs/plans/logbook-entries.md (chunk 2) in the
/// hobbs repo. Pilot in command/co-pilot are picked via [PilotPicker] against GET /pilot?search=
/// (see docs/plans/pilot-picker.md); aircraft is picked via [AircraftPicker] against
/// GET /aircraft?search= (see docs/plans/aircraft-picker.md); departure/arrival places are picked
/// via [AirfieldPicker] against GET /airfield?search= (see docs/plans/airfield-picker.md, chunk 6).
/// Holder's Operating Capacity is picked via [HolderOperatingCapacityField], a fixed-choice
/// dropdown rather than a search picker - see docs/plans/holder-operating-capacity.md.
/// The legacy free-text departurePlace/arrivalPlace fields have been dropped from the backend
/// contract entirely - departureAirfieldId/arrivalAirfieldId are now required, mirroring how
/// aircraftId/pilotInCommandId already work - so this screen just passes the picked [Airfield]'s
/// id straight through to [FlightApi.createFlightEntry]; a pilot can no longer type an arbitrary
/// place, only pick one of the seeded airfields.
///
/// On [initState], prefetches everything the five pickers need via a single
/// GET /flight-entry-context call (see docs/plans/flight-entry-context-prefetch.md), passed down
/// as each picker's `initialSuggestions` so the first on-focus load is synchronous instead of a
/// per-picker network round trip.
class CreateFlightEntryScreen extends StatefulWidget {
  const CreateFlightEntryScreen(
      {super.key, required this.session, this.httpClient});

  final Session session;

  /// Overridable for tests - see test/create_flight_entry_screen_test.dart.
  final http.Client? httpClient;

  @override
  State<CreateFlightEntryScreen> createState() =>
      _CreateFlightEntryScreenState();
}

class _CreateFlightEntryScreenState extends State<CreateFlightEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _singleEngineMinutesController = TextEditingController(text: '0');
  final _multiEngineMinutesController = TextEditingController(text: '0');
  final _totalMinutesController = TextEditingController();
  final _nightMinutesController = TextEditingController(text: '0');
  final _ifrMinutesController = TextEditingController(text: '0');
  final _crossCountryMinutesController = TextEditingController(text: '0');
  final _pilotInCommandMinutesController = TextEditingController(text: '0');
  final _coPilotMinutesController = TextEditingController(text: '0');
  final _dualMinutesController = TextEditingController(text: '0');
  final _instructorMinutesController = TextEditingController(text: '0');
  final _dayLandingsController = TextEditingController(text: '0');
  final _nightLandingsController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _departureTime = TimeOfDay.now();
  TimeOfDay _arrivalTime = TimeOfDay.now();

  // Defaults to the caller themselves - the common solo-flight case - still editable/clearable
  // for a dual/instructed flight. Co-pilot has no such default; most flights don't have one.
  late PilotSummary? _pilotInCommand =
      PilotSummary(id: widget.session.pilotId, name: widget.session.name);
  PilotSummary? _coPilot;
  String? _pilotInCommandError;
  Aircraft? _aircraft;
  String? _aircraftError;
  Airfield? _departureAirfield;
  String? _departureAirfieldError;
  Airfield? _arrivalAirfield;
  String? _arrivalAirfieldError;
  String? _holderOperatingCapacity;
  String? _holderOperatingCapacityError;

  bool _submitting = false;
  String? _error;
  FlightEntry? _created;

  // Prefetched once via GET /flight-entry-context (see
  // docs/plans/flight-entry-context-prefetch.md) so the five pickers below can skip their own
  // on-focus fetch. Fire-and-forget, not awaited by a FutureBuilder gating the form - a pilot who
  // focuses a picker before this lands just gets that picker's own unchanged on-focus fetch, and a
  // failed prefetch is swallowed silently since every picker already has that same fallback.
  FlightEntryContext? _context;

  @override
  void initState() {
    super.initState();
    FlightEntryContextApi.fetch(
      sessionId: widget.session.sessionId,
      client: widget.httpClient,
    ).then((result) {
      if (mounted) setState(() => _context = result);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _singleEngineMinutesController.dispose();
    _multiEngineMinutesController.dispose();
    _totalMinutesController.dispose();
    _nightMinutesController.dispose();
    _ifrMinutesController.dispose();
    _crossCountryMinutesController.dispose();
    _pilotInCommandMinutesController.dispose();
    _coPilotMinutesController.dispose();
    _dualMinutesController.dispose();
    _instructorMinutesController.dispose();
    _dayLandingsController.dispose();
    _nightLandingsController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool departure) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: departure ? _departureTime : _arrivalTime,
    );
    if (picked == null) return;
    setState(() {
      if (departure) {
        _departureTime = picked;
      } else {
        _arrivalTime = picked;
      }
    });
  }

  DateTime _combine(TimeOfDay time) =>
      DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  int _intOr0(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  /// The paired-minutes rows shown before the cross-country field, declared once instead of
  /// hand-written per row.
  late final _minutesFieldPairsBeforeCrossCountry = [
    (
      _singleEngineMinutesController,
      'Single-engine',
      _multiEngineMinutesController,
      'Multi-engine'
    ),
    (_nightMinutesController, 'Night', _ifrMinutesController, 'IFR'),
  ];

  /// The paired-minutes rows shown after the cross-country field.
  late final _minutesFieldPairsAfterCrossCountry = [
    (
      _pilotInCommandMinutesController,
      'PIC minutes (this logbook)',
      _coPilotMinutesController,
      'Co-pilot minutes'
    ),
    (
      _dualMinutesController,
      'Dual',
      _instructorMinutesController,
      'Instructor'
    ),
    (
      _dayLandingsController,
      'Day landings',
      _nightLandingsController,
      'Night landings'
    ),
  ];

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    final picMissing = _pilotInCommand == null;
    final aircraftMissing = _aircraft == null;
    final departureAirfieldMissing = _departureAirfield == null;
    final arrivalAirfieldMissing = _arrivalAirfield == null;
    final holderOperatingCapacityMissing = _holderOperatingCapacity == null;
    setState(() {
      _pilotInCommandError = picMissing ? 'Required' : null;
      _aircraftError = aircraftMissing ? 'Required' : null;
      _departureAirfieldError = departureAirfieldMissing ? 'Required' : null;
      _arrivalAirfieldError = arrivalAirfieldMissing ? 'Required' : null;
      _holderOperatingCapacityError =
          holderOperatingCapacityMissing ? 'Required' : null;
    });
    if (!formValid ||
        picMissing ||
        aircraftMissing ||
        departureAirfieldMissing ||
        arrivalAirfieldMissing ||
        holderOperatingCapacityMissing) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await FlightApi.createFlightEntry(
        sessionId: widget.session.sessionId,
        aircraftId: _aircraft!.id,
        date: _date,
        departureTime: _combine(_departureTime),
        arrivalTime: _combine(_arrivalTime),
        departureAirfieldId: _departureAirfield!.id,
        arrivalAirfieldId: _arrivalAirfield!.id,
        pilotInCommandId: _pilotInCommand!.id,
        coPilotId: _coPilot?.id,
        holderOperatingCapacity: _holderOperatingCapacity!,
        singleEngineMinutes: _intOr0(_singleEngineMinutesController),
        multiEngineMinutes: _intOr0(_multiEngineMinutesController),
        totalMinutes: _intOr0(_totalMinutesController),
        nightMinutes: _intOr0(_nightMinutesController),
        ifrMinutes: _intOr0(_ifrMinutesController),
        crossCountryMinutes: _intOr0(_crossCountryMinutesController),
        pilotInCommandMinutes: _intOr0(_pilotInCommandMinutesController),
        coPilotMinutes: _intOr0(_coPilotMinutesController),
        dualMinutes: _intOr0(_dualMinutesController),
        instructorMinutes: _intOr0(_instructorMinutesController),
        dayLandings: _intOr0(_dayLandingsController),
        nightLandings: _intOr0(_nightLandingsController),
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
        client: widget.httpClient,
      );
      setState(() => _created = created);
    } on ApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          400 => 'Check the entered fields - one or more is invalid.',
          404 =>
            'The aircraft or a picked pilot no longer exists - please re-check your selections.',
          _ => 'Could not save the entry (HTTP ${e.statusCode}).',
        };
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the backend: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_created != null) {
      return _FlightEntrySavedView(
        session: widget.session,
        httpClient: widget.httpClient,
        created: _created!,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log a flight')),
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AircraftPicker(
                  key: const Key('aircraftPicker'),
                  sessionId: widget.session.sessionId,
                  label: 'Aircraft',
                  errorText: _aircraftError,
                  httpClient: widget.httpClient,
                  initialSuggestions: _context?.recentAircraft,
                  onChanged: (aircraft) => setState(() {
                    _aircraft = aircraft;
                    if (aircraft != null) _aircraftError = null;
                  }),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${formatDate(_date)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                AirfieldPicker(
                  key: const Key('departureAirfieldPicker'),
                  sessionId: widget.session.sessionId,
                  label: 'Departure place',
                  errorText: _departureAirfieldError,
                  httpClient: widget.httpClient,
                  initialSuggestions: _context?.recentAirfields,
                  onChanged: (airfield) => setState(() {
                    _departureAirfield = airfield;
                    if (airfield != null) _departureAirfieldError = null;
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text('Departure time: ${_departureTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _pickTime(true),
                ),
                const SizedBox(height: 12),
                AirfieldPicker(
                  key: const Key('arrivalAirfieldPicker'),
                  sessionId: widget.session.sessionId,
                  label: 'Arrival place',
                  errorText: _arrivalAirfieldError,
                  httpClient: widget.httpClient,
                  initialSuggestions: _context?.recentAirfields,
                  onChanged: (airfield) => setState(() {
                    _arrivalAirfield = airfield;
                    if (airfield != null) _arrivalAirfieldError = null;
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Arrival time: ${_arrivalTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _pickTime(false),
                ),
                const SizedBox(height: 12),
                PilotPicker(
                  key: const Key('pilotInCommandPicker'),
                  sessionId: widget.session.sessionId,
                  label: 'Pilot in command',
                  initialValue: _pilotInCommand,
                  errorText: _pilotInCommandError,
                  httpClient: widget.httpClient,
                  initialSuggestions: _context?.knownPilots,
                  onChanged: (pilot) => setState(() {
                    _pilotInCommand = pilot;
                    if (pilot != null) _pilotInCommandError = null;
                  }),
                ),
                const SizedBox(height: 12),
                PilotPicker(
                  key: const Key('coPilotPicker'),
                  sessionId: widget.session.sessionId,
                  label: 'Co-pilot (optional)',
                  httpClient: widget.httpClient,
                  initialSuggestions: _context?.knownPilots,
                  onChanged: (pilot) => setState(() => _coPilot = pilot),
                ),
                const SizedBox(height: 12),
                HolderOperatingCapacityField(
                  key: const Key('holderOperatingCapacityField'),
                  label: 'Capacity',
                  value: _holderOperatingCapacity,
                  errorText: _holderOperatingCapacityError,
                  onChanged: (capacity) => setState(() {
                    _holderOperatingCapacity = capacity;
                    if (capacity != null) _holderOperatingCapacityError = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _totalMinutesController,
                  decoration: const InputDecoration(labelText: 'Total minutes'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Required';
                    if (n < 0) return 'Cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                for (final (aController, aLabel, bController, bLabel)
                    in _minutesFieldPairsBeforeCrossCountry) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _MinutesField(
                            controller: aController, label: aLabel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MinutesField(
                            controller: bController, label: bLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _crossCountryMinutesController,
                  decoration:
                      const InputDecoration(labelText: 'Cross-country minutes'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                for (final (aController, aLabel, bController, bLabel)
                    in _minutesFieldPairsAfterCrossCountry) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _MinutesField(
                            controller: aController, label: aLabel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MinutesField(
                            controller: bController, label: bLabel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _remarksController,
                  decoration:
                      const InputDecoration(labelText: 'Remarks (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled numeric minutes field, with no dependency on the enclosing [State] - keeps
/// promoting it to `lib/widgets/` a mechanical move once the edit-flight-entry screen's shape is
/// known (see docs/plans/split-create-flight-entry-screen.md).
class _MinutesField extends StatelessWidget {
  const _MinutesField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
      );
}

/// The post-submit "Flight logged" confirmation, shown in place of the form once an entry has
/// been created.
class _FlightEntrySavedView extends StatelessWidget {
  const _FlightEntrySavedView({
    required this.session,
    required this.httpClient,
    required this.created,
  });

  final Session session;
  final http.Client? httpClient;
  final FlightEntry created;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Flight logged')),
        body: ResponsivePage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text('Flight entry saved.'),
              const SizedBox(height: 8),
              SelectableText('Entry id: ${created.id}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => ViewFlightEntryScreen(
                              session: session,
                              initialFlightEntryId: created.id,
                              httpClient: httpClient,
                            ))),
                child: const Text('View it'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(created),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
}
