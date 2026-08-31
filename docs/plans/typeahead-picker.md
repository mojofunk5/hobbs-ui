# Plan: Extract a shared `TypeaheadPicker<T>`

**Status:** Designed 2026-08-31. The "Revision: on-focus loading" behaviour (AirfieldPicker/
AircraftPicker's on-focus GET /airfield/recent and GET /aircraft/recent calls) implemented
2026-08-31, directly in the existing three hand-rolled pickers - the `TypeaheadPicker<T>`
extraction itself remains not yet implemented, per this doc's own "gets designed as its own doc PR
... implemented in a new session" note above; a future session extracting it should build the
`onFocusLoad` API against the already-shipped on-focus behaviour, not the other way round. Revised
2026-08-31 to fold in the on-focus
redesign below - see "Revision: on-focus loading" for what changed and why.

## Context

See `docs/architecture-brief.md`'s 2026-08-31 decision entry for why now: `PilotPicker`,
`AirfieldPicker`, and `AircraftPicker` (`lib/widgets/`) are three independently hand-rolled
typeahead widgets sharing one UX pattern. The 2026-08-30 typeahead-UX fix had to touch the same
debounce timer, out-of-order-response guard, and suggestion-list chrome in all three files for one
conceptual change - the 3x-maintenance cost this project's bare-bones stance (Non-goal #3) is meant
to guard against once it's real, not hypothetical.

Read all three current files before touching this plan - `_PilotPickerState`, `_AirfieldPickerState`,
`_AircraftPickerState` in `lib/widgets/{pilot,airfield,aircraft}_picker.dart`.

### What's identical across all three today
- `_debounceDelay` (300ms), the debounce `Timer`
- `_searchSeq` - the out-of-order-response guard (a fast typist can have two searches in flight;
  only the most-recently-issued one's response is allowed to apply)
- `_selected` / `_suggestions` / `_searching` / `_searched` state and their transitions
- The `TextField` + `InputDecoration` shape: label, error text, a spinner while searching, a
  light-blue `Icons.cancel` clear button once something's selected
- The suggestion list: bordered `Container` (max height 200) wrapping a `ListView` of `ListTile`s

### What genuinely varies per picker
| | `PilotPicker` | `AirfieldPicker` | `AircraftPicker` |
| --- | --- | --- | --- |
| Search call | `PilotApi.search` | `AirfieldApi.search` | `AircraftApi.search(..., registrationOnly: true)` |
| Loads full set on focus (empty query)? | Yes | Yes | No - `minSearchLength` (2) gate instead |
| "Create new" inline option | Yes | No (reference data) | No (reference data) |
| No-matches helper text | "No matches - create a new pilot below" | "No airfields found - check the spelling and try again" | "No aircraft found - check the registration and try again" |
| Below-min-length helper text | n/a | n/a | "Type at least 2 characters of the registration" |
| Item label | `pilot.name` | `airfield.displayLabel` | `aircraft.displayLabel` |

## Confirmed decisions

- **New file, `lib/widgets/typeahead_picker.dart`.** This is the one case in this codebase so far
  where rule 2 of `ai-working-agreement.md` ("don't over-engineer") points *toward* a new
  abstraction rather than against one - three real call sites already exist, unlike the
  `_MinutesField` case in `split-create-flight-entry-screen.md`, which stayed private for lack of a
  second confirmed consumer.
- **`TypeaheadPicker<T>` owns all the state.** `_selected`, `_suggestions`, `_searching`,
  `_searched`, the debounce `Timer`, and `_searchSeq` all move into
  `_TypeaheadPickerState<T>`. Nothing behavioural changes from today's three implementations - this
  is a pure extraction, not a UX redesign.
- **`PilotPicker`/`AirfieldPicker`/`AircraftPicker` become thin `StatelessWidget` wrappers** around
  `TypeaheadPicker<PilotSummary|Airfield|Aircraft>`, keeping their existing public constructors
  (`sessionId`, `label`, `onChanged`, `initialValue`, `errorText`, `httpClient`) unchanged so no call
  site in `create_flight_entry_screen.dart` or elsewhere needs to change. `AircraftPicker.minSearchLength`
  stays a public static const on `AircraftPicker` itself (referenced by
  `test/aircraft_picker_test.dart` today) and is passed through to `TypeaheadPicker.minQueryLength`.
- **Proposed `TypeaheadPicker<T>` API** - covers exactly the variance in the table above, nothing
  more:

  ```dart
  class TypeaheadPicker<T> extends StatefulWidget {
    const TypeaheadPicker({
      super.key,
      required this.label,
      required this.search,
      required this.itemLabel,
      required this.onChanged,
      required this.noMatchesHelperText,
      this.initialValue,
      this.errorText,
      this.onFocusLoad,
      this.minQueryLength = 0,
      this.belowMinLengthHelperText,
      this.createOption,
    }) : assert(minQueryLength == 0 || belowMinLengthHelperText != null);

    final String label;
    final Future<List<T>> Function(String? query) search;
    final String Function(T item) itemLabel;
    final ValueChanged<T?> onChanged;
    final String noMatchesHelperText;
    final T? initialValue;
    final String? errorText;

    /// Populates the suggestion list as soon as the field gains focus, before anything's typed -
    /// null means this picker has no such behaviour (none of the three current pickers land here;
    /// kept nullable for a future picker that has no sane "browse before typing" affordance at
    /// all, e.g. one over a dataset with neither a small full set nor a "recent" concept). Also
    /// what [TypeaheadPicker]'s clear button calls to re-open the list immediately - one callback
    /// drives both, since a picker that can browse on focus can always re-browse after clearing.
    /// See "Revision: on-focus loading" below for why this isn't just `search(null)` for
    /// Airfield/Aircraft.
    final Future<List<T>> Function()? onFocusLoad;

    /// Below this many characters, no search fires at all (Aircraft's 2-char gate against a
    /// ~600k-row backend). 0 means no minimum. Independent of [onFocusLoad] - Aircraft sets both:
    /// a recent-items dropdown before typing, and a minimum length once typing starts.
    final int minQueryLength;

    /// Required when [minQueryLength] > 0 - shown while the typed query is shorter than it.
    final String? belowMinLengthHelperText;

    /// Non-null only for pickers that can create a new item inline (Pilot).
    final TypeaheadCreateOption<T>? createOption;

    @override
    State<TypeaheadPicker<T>> createState() => _TypeaheadPickerState<T>();
  }

  class TypeaheadCreateOption<T> {
    const TypeaheadCreateOption({
      required this.create,
      required this.tileLabel,
    });

    final Future<T> Function(String query) create;
    final String Function(String query) tileLabel;
  }
  ```

  Notes on choices baked into that shape:
  - `search` takes the already-trimmed, nullable query (`null` meaning "load everything", used only
    by Pilot's `onFocusLoad`) - matches every current `*Api.search`'s own signature, so each
    wrapper's `search:` argument is a one-line pass-through
    (`(query) => PilotApi.search(sessionId: sessionId, query: query, client: httpClient)`) with no
    adapting logic in the wrapper.
  - No generic `helperText` builder callback - considered, rejected as over-engineering for three
    known cases. The two concrete strings (`noMatchesHelperText`, `belowMinLengthHelperText`) match
    what's actually needed and stay just as easy to read at each call site as a lambda would.

## Revision: on-focus loading (2026-08-31)

The original version of this plan gave `TypeaheadPicker` a `bool loadOnFocus` that, when true,
called `search(null)` on focus - a direct port of `PilotPicker`/`AirfieldPicker`'s existing
behaviour, `minQueryLength > 0` and `loadOnFocus` were asserted mutually exclusive.

Superseded before implementation, prompted by two things surfacing together while investigating a
live bug (`AirfieldPicker` showing "No airfields found" immediately on focus, before typing) - full
diagnosis lives in this session's transcript, not repeated here:

1. **`AirfieldPicker`'s `loadOnFocus` behaviour was fetching the entire ~1,200-row `airfield` table
   just to show 5 recently-flown ones at the top** (`Logbook.searchAirfields`'s recent-first splice -
   see `hobbs`'s `docs/plans/picker-recent-endpoints.md`, designed alongside this revision). A
   direct `search(null)` port would have carried that waste into the shared widget rather than
   fixing it.
2. **`AircraftPicker` has no on-focus behaviour at all today** - reasonable given aircraft's
   ~600k-row scale, but it means a pilot can't quickly repick their last-flown aircraft the way they
   can for pilot/airfield. Worth fixing at the same time rather than leaving a widget-level
   inconsistency the abstraction would otherwise bake in permanently.

Both are fixed by `hobbs` adding two new endpoints, `GET /airfield/recent` and `GET /aircraft/recent`
(pilot's own last 5 distinct flown airfields/aircraft, most-recent first - see the linked plan for
the full backend design). `TypeaheadPicker.onFocusLoad` is deliberately a plain
`Future<List<T>> Function()` rather than reusing `search` with a null query, since Airfield/Aircraft
now populate it from an entirely different endpoint than their `search` callback hits:

- **Pilot:** `onFocusLoad: () => search(null)` - unchanged behaviour, still backed by
  `GET /pilot?search=` with no query. This dataset is genuinely small per pilot (privacy-scoped to
  people they've flown with - see `hobbs`'s `docs/plans/pilot-picker.md`), so loading it in full on
  focus was never the problem and isn't being redesigned.
- **Airfield:** `onFocusLoad: () => AirfieldApi.recent(sessionId: sessionId, client: httpClient)` -
  new `AirfieldApi.recent` method hitting `GET /airfield/recent`, replacing the old
  `search(null)`-on-focus call. Fixes the payload-size problem and - since it's a materially simpler
  request/response than the old full-table-plus-splice path - plausibly fixes the reported bug as a
  side effect, though the bug's root cause in the old code was never conclusively pinned down; this
  should be verified once implemented, not assumed.
- **Aircraft:** `onFocusLoad: () => AircraftApi.recent(sessionId: sessionId, client: httpClient)` -
  new capability, new `AircraftApi.recent` method hitting `GET /aircraft/recent`. Combined with
  `minQueryLength: AircraftPicker.minSearchLength` (unchanged) - the two are independent now that
  `onFocusLoad` isn't defined in terms of `search`, so a picker can browse recents before typing
  *and* still gate real searches behind a minimum length.
  - `createOption`'s `tileLabel` and `TypeaheadPicker`'s own "No matches - create a new X below"
    phrasing: the wrapper supplies both directly - `TypeaheadPicker` doesn't try to derive the
    "create a new pilot below" wording from an entity-name string, since inferring "pilot" from
    `PilotSummary`'s type or similar would be a worse abstraction than just letting `PilotPicker`
    pass its own literal string as `noMatchesHelperText` (unused by `PilotPicker` since
    `createOption` being non-null takes priority - see internal logic below).
- **Internal helper-text priority in `_TypeaheadPickerState.build()`** (selected == null only):
  1. `minQueryLength > 0 && query.length < minQueryLength` -> `belowMinLengthHelperText`
  2. `searched && !searching && suggestions.isEmpty && createOption != null` -> a fixed
     `'No matches - create a new below'`-shaped string, or `noMatchesHelperText` if the wrapper set
     one specifically for this case (`PilotPicker` does: "No matches - create a new pilot below")
  3. `searched && !searching && suggestions.isEmpty` -> `noMatchesHelperText`
  4. otherwise -> `null`
- **No new dependency, no state-management change.** Still `StatefulWidget` + `setState`, just one
  of them instead of three.

## Expected result

| File | Before | After (approx.) |
| --- | --- | --- |
| `lib/widgets/typeahead_picker.dart` (new) | - | ~230 |
| `lib/widgets/pilot_picker.dart` | 238 | ~35 |
| `lib/widgets/airfield_picker.dart` | 217 | ~25 |
| `lib/widgets/aircraft_picker.dart` | 226 | ~30 |

Net roughly flat in total lines, but any future picker-wide change (another shared UX fix, or a
fourth picker for a new entity) touches one file instead of three.

## Test impact

`test/{pilot,airfield,aircraft}_picker_test.dart` should keep passing unchanged in behaviour - the
public widgets keep their existing constructors and rendered output. Actually running them is the
verification step, not an assumption: the architecture brief's Testing section already flags that
`find.byType(TextField)` matches more than you'd expect, so confirm each suite's finders still
resolve uniquely once `TextField`/`ListTile` are nested one level deeper inside
`TypeaheadPicker` rather than built directly in `_PilotPickerState.build()` etc. Add
`test/typeahead_picker_test.dart` for the shared logic itself (debounce, race guard, min-length
gate, create-option flow) rather than re-testing it three times over via the wrappers.

## Explicitly out of scope (left for later)

- Any UX/behaviour change - this is a pure extraction, matching the 2026-08-30 decision's fixed
  behaviour exactly.
- A fourth picker or new entity type - nothing today needs one; this plan sizes the API to the
  three that exist, not to speculative future callers.
- Moving picker API calls (`PilotApi`/`AirfieldApi`/`AircraftApi`) - unchanged, still one typed
  class per entity per rule 4 of `ai-working-agreement.md`.
