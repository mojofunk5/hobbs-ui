import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/aircraft_api.dart';
import '../models/aircraft.dart';

/// A typeahead field for picking an aircraft against GET /aircraft?search=&registrationOnly=true
/// (see docs/plans/aircraft-picker.md in the hobbs repo) - replaces a raw pasted-in AircraftId text
/// field. Deliberately simpler than PilotPicker: no "create new" option - aircraft is reference
/// data, not pilot-submitted, so there's nothing to create inline - and no full-set dropdown on
/// focus, since the backend requires a search of at least [minSearchLength] characters rather than
/// defaulting to "everything" (~600k rows). See PilotPicker's own doc comment for why this is
/// hand-rolled rather than built on Flutter's Autocomplete widget.
///
/// Registration-only, not make/model, unlike BrowseAircraftScreen's search - a pilot logging a
/// flight already knows the tail number they flew, and a make/model match would surface every
/// aircraft of that type in the (eventually ~600k-row) dataset, not just the one they want.
///
/// Not itself a FormField - calls [onChanged] with the current selection (null while nothing's
/// been picked), same contract as PilotPicker.
class AircraftPicker extends StatefulWidget {
  const AircraftPicker({
    super.key,
    required this.sessionId,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.errorText,
    this.httpClient,
  });

  static const minSearchLength = 2;

  final String sessionId;
  final String label;
  final ValueChanged<Aircraft?> onChanged;
  final Aircraft? initialValue;
  final String? errorText;

  /// Overridable for tests - see test/aircraft_picker_test.dart.
  final http.Client? httpClient;

  @override
  State<AircraftPicker> createState() => _AircraftPickerState();
}

class _AircraftPickerState extends State<AircraftPicker> {
  static const _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _controller;

  Aircraft? _selected;
  List<Aircraft> _suggestions = [];
  bool _searching = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue?.displayLabel);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onChanged(null);
    }
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < AircraftPicker.minSearchLength) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    _debounce = Timer(_debounceDelay, () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _searched = false;
    });
    try {
      final results = await AircraftApi.search(
        sessionId: widget.sessionId,
        query: query,
        registrationOnly: true,
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
        _searched = true;
      });
    }
  }

  void _select(Aircraft aircraft) {
    setState(() {
      _selected = aircraft;
      _controller.text = aircraft.displayLabel;
      _suggestions = [];
      _searching = false;
      _searched = false;
    });
    widget.onChanged(aircraft);
  }

  @override
  Widget build(BuildContext context) {
    final noMatches = _selected == null &&
        _searched &&
        !_searching &&
        _suggestions.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
            helperText: _selected == null
                ? (noMatches
                    ? 'No aircraft found for that registration'
                    : 'Type at least ${AircraftPicker.minSearchLength} characters of the registration')
                : null,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _selected != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
          ),
          onChanged: _onTextChanged,
        ),
        if (_selected == null && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final aircraft in _suggestions)
                  ListTile(
                    dense: true,
                    title: Text(aircraft.displayLabel),
                    onTap: () => _select(aircraft),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
