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
  final _focusNode = FocusNode();

  Aircraft? _selected;
  List<Aircraft> _suggestions = [];
  bool _searching = false;
  bool _searched = false;
  Timer? _debounce;

  // Guards against an out-of-order response: cancelling _debounce only stops a *future* timer
  // firing, it can't cancel a request that's already in flight, so typing fast enough to have two
  // searches in flight at once used to let an earlier, slower request's response land after a
  // later one's and silently overwrite it with stale results. Each _search call captures its own
  // sequence number and only applies its response if nothing newer has been issued since.
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue?.displayLabel);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
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
    // Shown from the keystroke itself, not from when the debounced search actually starts - a
    // 300ms window with zero feedback read as "did this even register?" to a real user, even
    // though it was only ever a debounce, not a hang.
    setState(() => _searching = true);
    _debounce = Timer(_debounceDelay, () => _search(query));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
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
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = results;
        _searching = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
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

  /// Lets a pilot pick a different aircraft without first deleting the current selection's text
  /// by hand - previously the only way back into search was to select-all-and-retype, with no
  /// visible sign a selection even existed beyond a small green checkmark. Unlike PilotPicker/
  /// AirfieldPicker, doesn't re-search immediately afterwards - this picker requires
  /// [AircraftPicker.minSearchLength] characters before it searches at all, so there'd be nothing
  /// to show yet regardless.
  void _clear() {
    setState(() {
      _selected = null;
      _controller.clear();
      _suggestions = [];
      _searching = false;
      _searched = false;
    });
    widget.onChanged(null);
    _focusNode.requestFocus();
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
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
            helperText: _selected == null
                ? (noMatches
                    ? 'No aircraft found - check the registration and try again'
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
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.lightBlue),
                        tooltip: 'Clear',
                        onPressed: _clear,
                      )
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
