# Plan: Split up `CreateFlightEntryScreen`

**Status:** Designed 2026-08-30, not yet implemented.

## Context

`create_flight_entry_screen.dart` is 440 lines, the largest file in this app by a wide margin (next
is `reset_password_screen.dart` at 245). Flagged while reviewing the codebase for technical debt
alongside `hobbs`'s own integration-test file, which had grown the same way - one file quietly
absorbing all of a feature's growth with nothing prompting a reconsideration of its shape.

Unlike that case, this isn't several unrelated concerns mixed into one class - it's genuinely one
cohesive form (the CAP804/FCL.050 logbook entry, per `hobbs`'s `docs/plans/logbook-entries.md`), just
a long one: 16 `TextEditingController`s, one per numeric field, and a `build()` method that's mostly a
flat list of `TextFormField`s. The length comes from two things, not many:

- **Ten of the sixteen numeric fields are laid out as five near-identical
  `Row(children: [Expanded(TextFormField(...)), Expanded(TextFormField(...))])` pairs** (single/multi
  engine, night/IFR, PIC/co-pilot minutes, dual/instructor, day/night landings) - about 100 lines of
  structurally repetitive boilerplate differing only in controller and label.
- **The post-submit "Flight logged" success view is a second, fully separate UI state** (~35 lines)
  living in the same `build()` method as the form itself, despite sharing no widgets with it.

## Confirmed decisions

- **No new files.** Per `docs/ai-working-agreement.md` rule 2 ("work within existing modules, don't
  over-engineer"), this stays a single-file change - both extractions below are private
  classes/functions inside `create_flight_entry_screen.dart`, not new screens or widget files. The
  problem here is a messy `build()` method, not a genuine multi-screen concern the way `hobbs`'s admin
  vs. auth vs. pilot tests were.
- **Extract a small private `_MinutesField` helper** (label + `TextEditingController`) and build the
  five paired rows from a declarative list of `(controller, label)` pairs instead of five hand-written
  `Row`/`Expanded` blocks. Collapses ~100 lines of repetition to roughly 20-30.
  - **Considered making this a shared `lib/widgets/` file now, since Open work item 2 (editing a
    flight entry) will need the same editable fields** - `view_flight_entry_screen.dart` already
    duplicates this field list today, just as read-only `_row(label, value)`s, so the duplication
    pressure is real, not hypothetical. Decided to keep it private for now: we don't yet know whether
    editing will be a new screen (a real second consumer, worth a shared file) or `CreateFlightEntryScreen`
    itself gaining an edit mode (no second consumer at all), and designing a shared widget's API
    before either is settled means guessing at requirements (initial values, disabled fields,
    validation differences) no caller has stated yet. Writing `_MinutesField` with no dependencies on
    the enclosing `State` keeps promoting it to `lib/widgets/` a trivial, mechanical move once the
    edit screen's real shape is known - not a design cost paid twice.
- **Extract the post-submit success view into a private `_FlightEntrySavedView` `StatelessWidget`**
  in the same file, taking `session`, `httpClient`, and the created `FlightEntry` as constructor
  params. Removes the second `build()` branch from the main widget entirely - `build()` becomes just
  "if created, show `_FlightEntrySavedView`; otherwise show the form."
- **Leave everything else as-is**: the top identifying fields (aircraft id, date/time pickers, both
  `PilotPicker`s, the standalone total-minutes and cross-country fields, remarks) are heterogeneous
  enough that further extraction would cost more readability than it buys.
- **No new packages, no state-management change.** Still a plain `StatefulWidget` with `setState` -
  this is a widget-composition cleanup, not an architecture change.

## Expected result

Rough sizing, not a binding checklist:

| Piece | Approx. lines removed from main file |
| --- | --- |
| `_MinutesField` helper + declarative row list | ~70-80 |
| `_FlightEntrySavedView` extraction | ~30 |

`create_flight_entry_screen.dart` lands somewhere around 320-340 lines afterward - still the largest
file in the app (this is a genuinely large form), but with the repetitive and unrelated parts pulled
out of the main `build()` method, and future diffs to either piece scoped to a small, obviously-named
chunk instead of buried in a 440-line file.

## Explicitly out of scope (left for later)

- Any behavior change - this is a pure widget-composition refactor, no new validation, no field
  changes.
- The aircraft picker (`CLAUDE.md`'s Open work notes this as not yet designed) - `_aircraftIdController`
  stays a plain text field for now, unrelated to this split.
- Further splitting if the file keeps growing later (e.g. once an aircraft picker or a location
  picker lands here) - revisit then, not preemptively.
