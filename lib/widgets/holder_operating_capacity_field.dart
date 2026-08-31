import 'package:flutter/material.dart';

/// The 10 valid `holderOperatingCapacity` wire values, matching hobbs's
/// `HolderOperatingCapacity` enum exactly (see docs/plans/holder-operating-capacity.md). Labels
/// are a mechanical humanisation of the enum constant's own name (underscores to spaces, title
/// case), not the CAA notation (`P1`, `P.u/t`, etc.) - that shorthand and what it means stays
/// backend-only, per the plan's "keeps the CAA notation table out of hobbs-ui entirely" design:
/// this picker only ever needs to know the 10 valid values it can send, not what each one stands
/// for. A read view shows the real notation instead, via [FlightEntry.holderOperatingCapacityNotation]
/// - server-derived, never re-built from this list.
const _holderOperatingCapacityValues = [
  'PILOT_IN_COMMAND',
  'PILOT_IN_COMMAND_UNDER_SUPERVISION',
  'SECOND_PILOT',
  'PILOT_UNDER_TRAINING',
  'NAVIGATOR',
  'NAVIGATOR_UNDER_SUPERVISION',
  'NAVIGATOR_UNDER_TRAINING',
  'RADIOTELEPHONY_OPERATOR',
  'RADIOTELEPHONY_OPERATOR_UNDER_TRAINING',
  'FLIGHT_ENGINEER',
];

String _humanize(String value) => value
    .split('_')
    .map((word) =>
        '${word[0]}${word.substring(1).toLowerCase()}')
    .join(' ');

/// A fixed-choice dropdown for `FlightEntry.holderOperatingCapacity` - unlike
/// AircraftPicker/AirfieldPicker/PilotPicker, this isn't a typeahead search against a growing
/// backend reference table; it's a closed, unchanging set of 10 CAA-defined values, so a plain
/// dropdown over a hardcoded list is the right tool rather than a search widget.
///
/// Not itself a FormField - calls [onChanged] with the raw enum value (null while nothing's been
/// picked), and the parent screen surfaces a "Required" error via [errorText] on a failed submit,
/// the same convention the other flight-entry pickers use.
class HolderOperatingCapacityField extends StatelessWidget {
  const HolderOperatingCapacityField({
    super.key,
    required this.label,
    required this.onChanged,
    this.value,
    this.errorText,
  });

  final String label;
  final ValueChanged<String?> onChanged;
  final String? value;
  final String? errorText;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, errorText: errorText),
        items: [
          for (final capacity in _holderOperatingCapacityValues)
            DropdownMenuItem(
              value: capacity,
              child: Text(_humanize(capacity), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      );
}
