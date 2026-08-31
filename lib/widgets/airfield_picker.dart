import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/airfield_api.dart';
import '../models/airfield.dart';

/// A typeahead field for picking an airfield against GET /airfield?search= (see
/// docs/plans/airfield-picker.md in the hobbs repo) - replaces a raw departure/arrival place text
/// field. Behaves like [PilotPicker]: search is optional against a small (~1,200-row GB) reference
/// set, so the field loads a browsable set as soon as it gains focus, before anything's been
/// typed - unlike [AircraftPicker]'s 2-character minimum, driven by that dataset's much larger
/// scale. But like [AircraftPicker], there's no "create new" option - airfield is reference data
/// seeded from OurAirports, not pilot-submitted, so there's nothing to create inline. Results are
/// shown in the order the backend returns them (the calling pilot's own recently-flown airfields
/// first, then alphabetical) - this widget does no re-ranking of its own. See PilotPicker's own doc
/// comment for why this is hand-rolled rather than built on Flutter's Autocomplete widget.
///
/// An empty query (on-focus, or the field cleared back to nothing while still focused) hits
/// GET /airfield/recent instead of GET /airfield?search= with no search - the calling pilot's own
/// last 5 flown airfields, not the full ~1,200-row GB table (see
/// docs/plans/picker-recent-endpoints.md in the hobbs repo). A real (non-empty) search still goes
/// through GET /airfield?search=, unchanged.
///
/// Not itself a FormField - calls [onChanged] with the current selection (null while nothing's
/// been picked), same contract as PilotPicker/AircraftPicker.
class AirfieldPicker extends StatefulWidget {
  const AirfieldPicker({
    super.key,
    required this.sessionId,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.initialSuggestions,
    this.errorText,
    this.httpClient,
  });

  final String sessionId;
  final String label;
  final ValueChanged<Airfield?> onChanged;
  final Airfield? initialValue;
  final String? errorText;

  /// A prefetched suggestion set (e.g. from GET /flight-entry-context) consumed on the very first
  /// on-focus load instead of this widget making its own GET /airfield/recent call - see
  /// docs/plans/flight-entry-context-prefetch.md. Null means "no prefetch available", falling back
  /// to today's own-fetch behaviour unchanged.
  final List<Airfield>? initialSuggestions;

  /// Overridable for tests - see test/airfield_picker_test.dart.
  final http.Client? httpClient;

  @override
  State<AirfieldPicker> createState() => _AirfieldPickerState();
}

class _AirfieldPickerState extends State<AirfieldPicker> {
  static const _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  Airfield? _selected;
  List<Airfield> _suggestions = [];
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
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // Loads a browsable set as soon as the field gains focus, before anything's been typed -
    // _search('') below hits GET /airfield/recent rather than the full reference table. A
    // prefetched initialSuggestions (read live off widget, not captured in initState) is consumed
    // instead when present, avoiding a redundant network call - see
    // docs/plans/flight-entry-context-prefetch.md.
    if (!_focusNode.hasFocus || _searched) return;
    if (widget.initialSuggestions != null) {
      setState(() {
        _suggestions = widget.initialSuggestions!;
        _searched = true;
      });
    } else {
      _search(_controller.text.trim());
    }
  }

  void _onTextChanged(String value) {
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onChanged(null);
    }
    // Shown from the keystroke itself, not from when the debounced search actually starts - a
    // 300ms window with zero feedback read as "did this even register?" to a real user, even
    // though it was only ever a debounce, not a hang.
    setState(() => _searching = true);
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    setState(() => _searching = true);
    try {
      // An empty query means "browse", not "search" - GET /airfield/recent is right-sized for
      // that (the calling pilot's own last 5 flown airfields), versus GET /airfield?search= with
      // no search, which returns the full ~1,200-row GB table.
      final results = query.isEmpty
          ? await AirfieldApi.recent(sessionId: widget.sessionId, client: widget.httpClient)
          : await AirfieldApi.search(
              sessionId: widget.sessionId,
              query: query,
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

  void _select(Airfield airfield) {
    setState(() {
      _selected = airfield;
      _controller.text = airfield.displayLabel;
      _suggestions = [];
      _searching = false;
    });
    widget.onChanged(airfield);
  }

  /// Lets a pilot pick a different airfield without first deleting the current selection's text
  /// by hand - previously the only way back into the suggestion list was to select-all-and-retype,
  /// with no visible sign a selection even existed beyond a small green checkmark.
  void _clear() {
    setState(() {
      _selected = null;
      _controller.clear();
      _suggestions = [];
      _searched = false;
    });
    widget.onChanged(null);
    // requestFocus() only re-triggers _onFocusChanged's "load everything" behaviour when the
    // field didn't already have focus (a no-op listener call otherwise, since this is usually
    // tapped while the field is already focused) - search explicitly either way rather than
    // depending on that transition.
    _focusNode.requestFocus();
    _search('');
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
            helperText: noMatches ? 'No airfields found - check the spelling and try again' : null,
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
                for (final airfield in _suggestions)
                  ListTile(
                    dense: true,
                    title: Text(airfield.displayLabel),
                    onTap: () => _select(airfield),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
