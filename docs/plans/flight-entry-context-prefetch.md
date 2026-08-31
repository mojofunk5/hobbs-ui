# Plan: consume `GET /flight-entry-context` in the create-flight-entry screen

**Status:** Designed 2026-08-31, implemented 2026-08-31 -
[hobbs-ui#36](https://github.com/mojofunk5/hobbs-ui/pull/36).

## Context

`hobbs`'s `docs/plans/new-entry-context-endpoint.md` (implemented,
[mojofunk5/hobbs#53](https://github.com/mojofunk5/hobbs/pull/53)) added `GET /flight-entry-context`,
a single call returning everything `CreateFlightEntryScreen`'s pickers need:

```json
{
  "recentAirfields": [ /* AirfieldDto[], same shape as GET /airfield/recent */ ],
  "recentAircraft": [ /* AircraftDto[], same shape as GET /aircraft/recent */ ],
  "knownPilots": [ /* PilotSummaryDto[], same shape as GET /pilot?search= with no query */ ]
}
```

Today, `CreateFlightEntryScreen` (`lib/screens/create_flight_entry_screen.dart`) builds five pickers -
`AircraftPicker`, two `AirfieldPicker`s (departure/arrival), and two `PilotPicker`s (PIC/co-pilot) -
each of which independently fetches its own on-focus suggestion list the moment it gains focus (see
`docs/plans/typeahead-picker.md`'s "Revision: on-focus loading"): `AirfieldPicker`/`AircraftPicker`
hit `GET /airfield/recent`/`GET /aircraft/recent`, `PilotPicker` hits `GET /pilot?search=` with no
query. `aircraftId`/`departureAirfieldId`/`arrivalAirfieldId`/`pilotInCommandId` are all required on
`FlightEntry`, so a pilot filling in this screen is essentially certain to focus every one of those -
that's exactly the case the backend plan sized `GET /flight-entry-context` for: one round trip for
the whole screen instead of one per focus, which matters on a poor connection.

This doc is the other half the backend plan explicitly left out of scope: how the pickers stop doing
their own on-focus fetch and instead consume a prefetched batch. Per `ai-working-agreement.md` rule
11 (mirrored here as the doc-PR-first convention `hobbs`'s `CLAUDE.md` also states), this gets
designed and merged as its own doc first; implementation starts as a new session against the merged
doc.

Read `lib/widgets/{pilot,airfield,aircraft}_picker.dart` before touching this plan - each widget's
`_onFocusChanged`/`_loadRecent`/`_search` is the exact hook point this plan changes. Note the shared
`TypeaheadPicker<T>` extraction planned in `docs/plans/typeahead-picker.md` has **not** been
implemented yet - the three pickers are still independently hand-rolled, so this plan (like the
on-focus-loading revision before it) wires directly into the three existing files rather than into an
abstraction that doesn't exist. A future `TypeaheadPicker` extraction should build its `onFocusLoad`-
plus-cache API against whatever this plan ships, not the other way round.

## Confirmed decisions

- **New model, `lib/models/flight_entry_context.dart`.** `FlightEntryContext` with three fields -
  `List<Airfield> recentAirfields`, `List<Aircraft> recentAircraft`, `List<PilotSummary>
  knownPilots` - `fromJson` delegating to `Airfield.fromJson`/`Aircraft.fromJson`/
  `PilotSummary.fromJson` per element, same pattern as every other model in `lib/models/`.
- **New API wrapper, `lib/api/flight_entry_context_api.dart`.** `FlightEntryContextApi.fetch({required
  sessionId, http.Client? client})` - a single `GET /flight-entry-context`, same shape as every other
  `*Api` class (see `AirfieldApi`/`PilotApi`).
- **`CreateFlightEntryScreen` fetches once, in `initState`.** A single `FlightEntryContext?
  _context` field, populated via `FlightEntryContextApi.fetch(...).then(...)` (fire-and-forget, not
  awaited by a `FutureBuilder` gating the whole form - see "Explicitly out of scope" for why this
  isn't a blocking load). On success, `setState(() => _context = result)`; on failure, leave
  `_context` null and swallow the error silently - every picker already has a working fallback (its
  own on-focus fetch, unchanged), so a failed prefetch degrades to exactly today's behaviour rather
  than needing its own error UI.
- **Widget API addition: `initialSuggestions`.** Each of `AirfieldPicker`, `AircraftPicker`,
  `PilotPicker` gains an optional constructor parameter, `List<Airfield>? initialSuggestions` /
  `List<Aircraft>? initialSuggestions` / `List<PilotSummary>? initialSuggestions` respectively -
  the "an `initialSuggestions`-shaped parameter, roughly" the backend plan anticipated. `CreateFlightEntryScreen`
  passes `_context?.recentAirfields` / `_context?.recentAircraft` / `_context?.knownPilots` into each
  picker's existing constructor call (both `AirfieldPicker`s get the same `recentAirfields` list, both
  `PilotPicker`s get the same `knownPilots` list).
- **Each picker's `_onFocusChanged` consumes the cache on the very first focus, when present.**
  Currently every picker's on-focus handler looks like:
  ```dart
  void _onFocusChanged() {
    if (_focusNode.hasFocus && !_searched) {
      _loadRecent(); // or _search(_controller.text.trim())
    }
  }
  ```
  This becomes (shape identical across all three, only the type/field name differs):
  ```dart
  void _onFocusChanged() {
    if (!_focusNode.hasFocus || _searched) return;
    if (widget.initialSuggestions != null) {
      setState(() {
        _suggestions = widget.initialSuggestions!;
        _searched = true;
      });
    } else {
      _loadRecent(); // or _search(_controller.text.trim())
    }
  }
  ```
  No network call, no spinner, when the cache is already there - it's synchronous. `widget.initialSuggestions`
  is read lazily, at the moment of focus, off the picker's live `widget` reference (not captured in
  `initState`), so a prefetch that's still in flight when the screen first builds still gets picked up
  correctly as long as it lands before the pilot actually focuses that field - see "Explicitly out of
  scope" for the case where it doesn't.
- **`_clear()` is unchanged - always goes back to the network, never back to the cache.** Matches the
  backend plan's own reasoning for keeping the individual endpoints around: "a picker re-fetching
  after being cleared and refocused - the batch snapshot from screen load goes stale the moment the
  pilot picks something and clears it again." Only the *first* on-focus load per picker instance
  consumes `initialSuggestions`; every subsequent load (via `_clear()`, or `AircraftPicker`'s
  empty-text-while-focused reload) is a fresh `_loadRecent()`/`_search()` call exactly as today.
- **`AircraftPicker`'s `minSearchLength` gate is untouched** - `initialSuggestions` only changes
  what happens *before* anything's typed (on-focus browse), same as today's `_loadRecent()` it's
  replacing in that one path.

## Expected result

| File | Change |
| --- | --- |
| `lib/models/flight_entry_context.dart` (new) | `FlightEntryContext` model, ~20 lines |
| `lib/api/flight_entry_context_api.dart` (new) | `FlightEntryContextApi.fetch`, ~20 lines |
| `lib/screens/create_flight_entry_screen.dart` | `initState` prefetch, `_context` field, five picker constructor calls gain `initialSuggestions:` |
| `lib/widgets/airfield_picker.dart` | `initialSuggestions` param + `_onFocusChanged` change (~10 lines) |
| `lib/widgets/aircraft_picker.dart` | same shape |
| `lib/widgets/pilot_picker.dart` | same shape |

## Test impact

- New `test/flight_entry_context_api_test.dart` (mirrors `test/airfield_api_test.dart` etc.) -
  fetch success and non-2xx-throws-`ApiException` cases.
- `test/{airfield,aircraft,pilot}_picker_test.dart` gain a case each: constructed with
  `initialSuggestions` set, focusing the field shows those suggestions immediately with no HTTP call
  made (assert on the fake/mock `http.Client`'s call count) - and a second case confirming `_clear()`
  still hits the network afterward (existing clear-and-refocus tests should mostly cover this once
  the fixture supplies `initialSuggestions`).
- `test/create_flight_entry_screen_test.dart` gains a case asserting the screen issues exactly one
  `GET /flight-entry-context` call on load, and that the five pickers receive the expected slices of
  its response. A case for the prefetch failing (should still render a usable, if slower, form via
  each picker's individual fallback) is worth adding given "Confirmed decisions" above leans on that
  fallback existing.

## Explicitly out of scope

- **Blocking the form on the prefetch.** Considered wrapping the form body in a `FutureBuilder` that
  shows a spinner until `GET /flight-entry-context` resolves - rejected: the whole point of this
  change is a *faster*-feeling screen, and gating the entire form behind one more round trip (rather
  than just the pickers' individual ones) would trade a several-small-delays problem for a single
  bigger one. The accepted race instead: a pilot who focuses a picker before the prefetch has landed
  just gets today's exact per-picker on-focus fetch for that one field - a graceful degradation, not
  a bug, and no worse than the current behaviour.
- **The `TypeaheadPicker<T>` extraction from `docs/plans/typeahead-picker.md`.** Still not
  implemented; this plan wires `initialSuggestions` into the three existing hand-rolled widgets. A
  future extraction folds this in as part of `TypeaheadPicker`'s `onFocusLoad`-adjacent API rather
  than this plan attempting both changes at once.
- **Caching the prefetch across screen visits, or refreshing it in the background.** One fetch per
  screen instance, matching the backend plan's own "no caching or memoizing" stance - `_context` is
  plain `State` on `_CreateFlightEntryScreenState`, gone the moment the screen is disposed.
- **Editing/amending a flight entry.** Not yet built (see `docs/architecture-brief.md`'s open work);
  the backend plan already flagged that "every required picker gets focused" may not hold for that
  screen, so whether it should prefetch at all is a separate, later question.
