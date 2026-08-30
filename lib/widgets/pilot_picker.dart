import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/pilot_api.dart';
import '../models/pilot_summary.dart';

/// A typeahead field for picking a pilot known to the caller (see GET /pilot?search= in
/// docs/plans/pilot-picker.md) - replaces a raw pasted-in PilotId text field. Hand-rolled rather
/// than built on Flutter's Autocomplete widget, since that widget's optionsBuilder is synchronous
/// and this needs an async backend search - same "hand-roll rather than fight the framework or add
/// a dependency" spirit as OtpCodeInput.
///
/// Not itself a FormField - this widget calls [onChanged] with the current selection (null while
/// nothing's been picked), and the parent screen is responsible for surfacing a "Required" error
/// via [errorText] on a failed submit attempt, the same way it would read a TextFormField's
/// validator result.
class PilotPicker extends StatefulWidget {
  const PilotPicker({
    super.key,
    required this.sessionId,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.errorText,
    this.httpClient,
  });

  final String sessionId;
  final String label;
  final ValueChanged<PilotSummary?> onChanged;
  final PilotSummary? initialValue;
  final String? errorText;

  /// Overridable for tests - see test/pilot_picker_test.dart.
  final http.Client? httpClient;

  @override
  State<PilotPicker> createState() => _PilotPickerState();
}

class _PilotPickerState extends State<PilotPicker> {
  static const _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  PilotSummary? _selected;
  List<PilotSummary> _suggestions = [];
  bool _searching = false;
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue?.name);
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
    // Loads the caller's full known-pilot set as soon as the field gains focus, before they've
    // typed anything - GET /pilot with no search param returns exactly that (bounded, no
    // pagination needed - see the plan doc), so this gives a browsable initial dropdown.
    if (_focusNode.hasFocus && !_searched) {
      _search(_controller.text.trim());
    }
  }

  void _onTextChanged(String value) {
    if (_selected != null) {
      setState(() => _selected = null);
      widget.onChanged(null);
    }
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await PilotApi.search(
        sessionId: widget.sessionId,
        query: query.isEmpty ? null : query,
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

  void _select(PilotSummary pilot) {
    setState(() {
      _selected = pilot;
      _controller.text = pilot.name;
      _suggestions = [];
      _searching = false;
    });
    widget.onChanged(pilot);
  }

  Future<void> _createNew(String name) async {
    setState(() => _searching = true);
    try {
      final created = await PilotApi.create(
        sessionId: widget.sessionId,
        name: name,
        client: widget.httpClient,
      );
      if (!mounted) return;
      _select(created);
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final showCreateOption =
        _searched && !_searching && _selected == null && query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
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
        if (_selected == null && (_suggestions.isNotEmpty || showCreateOption))
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
                for (final pilot in _suggestions)
                  ListTile(
                    dense: true,
                    title: Text(pilot.name),
                    onTap: () => _select(pilot),
                  ),
                if (showCreateOption)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add),
                    title: Text('Create pilot "$query"'),
                    onTap: () => _createNew(query),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
