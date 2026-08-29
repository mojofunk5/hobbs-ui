import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_exception.dart';
import '../api/flight_api.dart';
import '../format.dart';
import '../models/flight_entry.dart';
import '../models/session.dart';
import '../widgets/responsive_page.dart';
import 'view_flight_entry_screen.dart';

/// The CAP804/FCL.050 logbook entry form - see docs/plans/logbook-entries.md (chunk 2) in the
/// hobbs repo. aircraftId/pilotInCommandId/coPilotId are plain pasted-in ids for now: no
/// pilot/aircraft search picker exists yet (see that plan's "no pilot search endpoint" note), so
/// they're created ahead of time via POST /pilot or POST /aircraft and pasted in here.
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

  final _aircraftIdController = TextEditingController();
  final _departurePlaceController = TextEditingController();
  final _arrivalPlaceController = TextEditingController();
  final _pilotInCommandIdController = TextEditingController();
  final _coPilotIdController = TextEditingController();
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

  bool _submitting = false;
  String? _error;
  FlightEntry? _created;

  @override
  void dispose() {
    _aircraftIdController.dispose();
    _departurePlaceController.dispose();
    _arrivalPlaceController.dispose();
    _pilotInCommandIdController.dispose();
    _coPilotIdController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await FlightApi.createFlightEntry(
        sessionId: widget.session.sessionId,
        aircraftId: _aircraftIdController.text.trim(),
        date: _date,
        departurePlace: _departurePlaceController.text.trim(),
        departureTime: _combine(_departureTime),
        arrivalPlace: _arrivalPlaceController.text.trim(),
        arrivalTime: _combine(_arrivalTime),
        pilotInCommandId: _pilotInCommandIdController.text.trim(),
        coPilotId: _coPilotIdController.text.trim().isEmpty
            ? null
            : _coPilotIdController.text.trim(),
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
            'aircraftId, pilotInCommandId, or coPilotId does not match an existing record.',
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
      return Scaffold(
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
              SelectableText('Entry id: ${_created!.id}'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (_) => ViewFlightEntryScreen(
                              session: widget.session,
                              initialFlightEntryId: _created!.id,
                              httpClient: widget.httpClient,
                            ))),
                child: const Text('View it'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_created),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
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
                TextFormField(
                  controller: _aircraftIdController,
                  decoration: const InputDecoration(labelText: 'Aircraft id'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${formatDate(_date)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _departurePlaceController,
                  decoration:
                      const InputDecoration(labelText: 'Departure place'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text('Departure time: ${_departureTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _pickTime(true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _arrivalPlaceController,
                  decoration: const InputDecoration(labelText: 'Arrival place'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Arrival time: ${_arrivalTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _pickTime(false),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pilotInCommandIdController,
                  decoration:
                      const InputDecoration(labelText: 'Pilot in command id'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _coPilotIdController,
                  decoration: const InputDecoration(
                      labelText: 'Co-pilot id (optional)'),
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _singleEngineMinutesController,
                        decoration:
                            const InputDecoration(labelText: 'Single-engine'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _multiEngineMinutesController,
                        decoration:
                            const InputDecoration(labelText: 'Multi-engine'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nightMinutesController,
                        decoration: const InputDecoration(labelText: 'Night'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ifrMinutesController,
                        decoration: const InputDecoration(labelText: 'IFR'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _crossCountryMinutesController,
                  decoration:
                      const InputDecoration(labelText: 'Cross-country minutes'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pilotInCommandMinutesController,
                        decoration: const InputDecoration(
                            labelText: 'PIC minutes (this logbook)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _coPilotMinutesController,
                        decoration: const InputDecoration(
                            labelText: 'Co-pilot minutes'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dualMinutesController,
                        decoration: const InputDecoration(labelText: 'Dual'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _instructorMinutesController,
                        decoration:
                            const InputDecoration(labelText: 'Instructor'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dayLandingsController,
                        decoration:
                            const InputDecoration(labelText: 'Day landings'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nightLandingsController,
                        decoration:
                            const InputDecoration(labelText: 'Night landings'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
