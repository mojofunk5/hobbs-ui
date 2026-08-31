# Architecture brief - hobbs-ui

Mirrors [`things-ui`'s own architecture-brief.md](https://github.com/mojofunk5/things-ui/blob/main/docs/architecture-brief.md)
in shape; content is this project's own.

## 1. Purpose

A Flutter client for `hobbs`, a self-hosted PPL flight logbook backend. Today: authentication
(register, login, password reset) plus the create/view/list logbook-entry screens
(`docs/plans/done/logbook-entries.md` in `hobbs`) - pilot in command/co-pilot are picked via a typeahead
against `GET /pilot?search=` (`docs/plans/done/pilot-picker.md` in `hobbs`), and aircraft is picked via a
typeahead against `GET /aircraft?search=` (`docs/plans/done/aircraft-picker.md` in `hobbs`) - plus a
Browse Aircraft screen for searching the same reference data outside the flight-entry form.

## 2. Goals

- A working, deployed web client with real auth against the real backend
- Consistent, responsive behaviour across phone and desktop with minimal code
- Stay genuinely barebones - no dependency, abstraction, or pattern the app doesn't need yet

## 3. Non-goals (for now)

- A design system or component library - Material's defaults, used directly
- State management library (Provider/Riverpod/Bloc) - `StatefulWidget` + `setState` has been
  sufficient so far and should stay the default until it genuinely isn't
- Named routes / a router package - a fixed `MaterialApp.home` plus plain `Navigator.push` covers
  this app's linear flows; see the deep-link caveat below for the one place this shows a real limit
- Offline support / PWA installability - the Flutter web service worker was removed (see Decisions)

## 4. Tech stack

- Flutter (web today; iOS is planned - see Open Work)
- `package:http` - all backend calls
- `package:shared_preferences` - the only persistence, for both the session and the remembered-email
  convenience

## 5. Project structure

```
lib/
  api/
    api_base.dart        # apiBase constant - '/api' in prod (proxied by Caddy), overridable via
                          # --dart-define=API_BASE=... for local dev against a real backend
    api_exception.dart    # ApiException(statusCode) - see Testing/error-handling below
    auth_api.dart          # AuthApi - typed methods per endpoint, all backend calls go through here
  models/
    session.dart           # Session - mirrors the backend's SessionDto exactly
  screens/
    welcome_screen.dart
    login_screen.dart
    register_screen.dart
    reset_password_screen.dart
    signed_in_screen.dart
    startup_screen.dart    # decides Welcome vs SignedIn based on a persisted session
  widgets/
    responsive_page.dart   # every screen's body wrapper - see Architecture principles
    otp_code_input.dart    # 6-box numeric code input, hand-rolled
  session_store.dart        # persists the active Session - survives a reload, cleared on logout
  remembered_identifier.dart # persists just the login identifier for the "remember my email"
                             # checkbox - a separate, shorter-lived concern from SessionStore, see
                             # below
  main.dart                  # usePathUrlStrategy(), deep-link detection, MaterialApp
```

## 6. Architecture principles

### Responsive by default
Every screen wraps its body in `ResponsivePage`: full-width on phone (unchanged from the original
design), a bounded (480px) `Card` on screens ≥600px wide. Without this, content just floats in a sea
of blank space on a desktop-width window - it reads as an unstyled phone screen stranded there,
rather than an intentional layout.

### `SessionStore` vs `RememberedIdentifier` - different lifetimes, different purposes
Both are thin static wrappers over `SharedPreferences`, but they're deliberately separate:
- `SessionStore` holds the active `Session` - it's the difference between `StartupScreen` showing
  `WelcomeScreen` or `SignedInScreen`, cleared only on explicit logout.
- `RememberedIdentifier` holds just the login identifier string, purely a form-prefill convenience.
  Saved/cleared **only as part of a successful login submit** (not on every keystroke) - unchecking
  "Remember my email" and logging in again actively clears any previously remembered value.

Conflating these into one store would couple an auth decision (is the user signed in?) to a UX
convenience (what should the email field default to?) that should keep working even for someone who
isn't currently signed in.

### Error handling is status-code-only
`hobbs`'s auth endpoints never return a parseable JSON error body on failure - `AuthApi` throws
`ApiException(statusCode)` and every screen branches on the numeric code (e.g. login's 401 vs
register's 400/403). There's no generic error-parsing layer because there's no error shape to parse.

## 7. Deep-linking the password-reset email

`hobbs`'s actual reset email links to `{frontendBaseUrl}/reset-password?email=&code=` - a real path,
not a hash URL. `main.dart` calls `usePathUrlStrategy()` and reads `Uri.base` once at startup; if the
path/query match that shape, it skips `StartupScreen`'s session check entirely and opens straight
into `ResetPasswordScreen`'s confirm step with both fields locked and pre-filled (matching
`things-ui` locking the code field specifically when it arrived via a trusted link, vs.
editable+autofocused when typed in by hand).

**Known caveat:** Flutter's default `Router` resets the visible URL to `/` right after the initial
frame - a quirk of `usePathUrlStrategy()` without named routes/`onGenerateRoute`. The deep link still
works, since it's parsed once before that reset happens, but a mid-flow page reload would lose the
pre-fill. No worse than the rest of the app today, which has no other screen-state persistence across
a reload. Would need real named routes to fix properly - not worth it for one screen yet.

## 8. Testing

- `flutter analyze` / `flutter test` must both be clean before a change is considered complete
- HTTP-dependent screens are tested with `http`'s `MockClient`, injected via each screen's optional
  `httpClient` constructor parameter (e.g. `LoginScreen(httpClient: client)`) - never a real network
  call in a test
- Anything touching `SessionStore`/`RememberedIdentifier` needs
  `SharedPreferences.setMockInitialValues({})` in `setUp`
- **Gotcha:** `find.byType(TextField)` also matches the hidden `TextField`s inside every
  `TextFormField` - a screen with both a `TextFormField` and an `OtpCodeInput` needs
  `find.descendant(of: find.byType(OtpCodeInput), matching: find.byType(TextField))` to scope to just
  the OTP boxes, or index-based lookups silently point at the wrong field

## 9. Decisions

Reverse-chronological. Never delete an entry - a later decision that supersedes an earlier one says
so explicitly.

### Note (2026-08-31): the prefetch decision below is now implemented
The design described in the entry directly below shipped as
[hobbs-ui#36](https://github.com/mojofunk5/hobbs-ui/pull/36) the same day - `docs/plans/done/flight-entry-context-prefetch.md`'s
Status line is updated accordingly. Recorded as a fresh note rather than editing that entry's "not
yet implemented" text, per this section's own append-only convention.

### Decision (2026-08-31): consume `GET /flight-entry-context` as a prefetch, not a blocking load
`hobbs` added `GET /flight-entry-context` ([mojofunk5/hobbs#53](https://github.com/mojofunk5/hobbs/pull/53),
plan in `hobbs`'s `docs/plans/done/new-entry-context-endpoint.md`) - one call aggregating what
`GET /airfield/recent`/`GET /aircraft/recent`/`GET /pilot?search=` (no query) each return, sized for
`CreateFlightEntryScreen` specifically because its four required pickers are essentially certain to
all get focused. Full design for the UI side (new `FlightEntryContext` model/API wrapper, an
`initialSuggestions` parameter added to `AirfieldPicker`/`AircraftPicker`/`PilotPicker` so the very
first on-focus load per picker consumes the prefetched batch instead of hitting the network, `_clear()`
unchanged so a re-focus after clearing still goes back to the network) is in
`docs/plans/done/flight-entry-context-prefetch.md` - not yet implemented. Deliberately a non-blocking
fire-and-forget fetch in `initState` rather than gating the form behind a `FutureBuilder`: a pilot who
focuses a field before the prefetch lands just falls back to that picker's existing individual
on-focus fetch, which is exactly today's behaviour, not a regression - see the plan's "Explicitly out
of scope" for the full reasoning. Wires directly into the three hand-rolled pickers rather than into
`docs/plans/typeahead-picker.md`'s still-unimplemented `TypeaheadPicker<T>` extraction, same
precedent as the 2026-08-31 on-focus-loading revision below.

### Decision (2026-08-31): stop loading the full airfield table on focus; add a recent-aircraft browse too
Investigating a reported bug (departure/arrival airfield picker showing "No airfields found"
immediately on focus, before typing) surfaced that the fix belonged one level up from the bug
itself: `AirfieldPicker` was fetching the *entire* ~1,200-row GB airfield table on every focus, just
to show the calling pilot's own last 5 flown airfields at the top
(`Logbook.searchAirfields`'s recent-first splice, in `hobbs`). Rather than patch that path, `hobbs`
gains two new endpoints - `GET /airfield/recent` and `GET /aircraft/recent`, each capped at 5,
plan in `hobbs`'s `docs/plans/done/picker-recent-endpoints.md` - and the picker switches to calling the
right-sized one instead. Aircraft gains an on-focus recent-items dropdown it never had before as
part of the same change (previously it had no browse-before-typing affordance at all, unlike
Pilot/Airfield) - a deliberate, small scope addition alongside the fix, not scope creep: leaving
Aircraft inconsistent with the other two once the shared `TypeaheadPicker` (see the entry below)
exists would bake the inconsistency into the abstraction's design permanently.

Pilot is explicitly **not** part of this change - `GET /pilot?search=` with no query already returns
a small, privacy-scoped set (people the caller has flown with, not a reference table), so loading it
in full on focus was never the problem being solved here.

This revises, rather than replaces, the "extract a shared typeahead picker widget" decision directly
below - see `docs/plans/typeahead-picker.md`'s "Revision: on-focus loading" section for the updated
`TypeaheadPicker` API (`onFocusLoad` replaces the originally-planned `loadOnFocus` bool).

### Decision (2026-08-31): extract a shared typeahead picker widget
Non-goal #3 says no abstraction the app doesn't need yet - `PilotPicker`/`AirfieldPicker`/
`AircraftPicker` were each hand-rolled independently on that basis. The 2026-08-30 typeahead-UX
decision above is the point that stopped being true: fixing one shared UX problem (missing loading/
finished/no-results/clear feedback) meant editing the same debounce timer, sequence-number race
guard, and suggestion-list chrome in three near-identical files, and any future picker-wide change
(a new picker for a new entity, another shared UX fix) will cost the same 3x tax again. That's the
signal this project's bare-bones stance treats as "needs it now," not "adding it speculatively."

What's actually shared (~150 of ~200 lines per file): the debounce `Timer`, the `_searchSeq`
out-of-order-response guard, `_selected`/`_suggestions`/`_searching`/`_searched` state, the
`TextField` + spinner/clear-icon decoration, and the suggestion `Container`/`ListView`. What
genuinely varies per picker: the search call itself (including `AircraftPicker`'s
`minSearchLength` gate vs. the other two's load-everything-on-focus), an optional inline "create
new" flow (`PilotPicker` only), helper/no-matches copy, and the per-item label.

Plan: a generic `TypeaheadPicker<T>` in `lib/widgets/` taking a search callback
(`Future<List<T>> Function(String? query)`), a label extractor (`String Function(T)`), and optional
create-callback/helper-text/load-on-focus parameters; `PilotPicker`/`AirfieldPicker`/
`AircraftPicker` become thin typed wrappers around it. Per rule 11 of `ai-working-agreement.md`,
this gets designed as its own doc PR (fleshing out the widget's exact API) reviewed and merged
first, with the extraction itself implemented in a new session against the merged doc rather than
continuing straight from here.

### Decision (2026-08-30): typeahead picker UX conventions
`AircraftPicker`/`PilotPicker`/`AirfieldPicker` all share one hand-rolled typeahead pattern (see
`PilotPicker`'s own doc comment for why it's hand-rolled rather than built on Flutter's
`Autocomplete`). Reported as "clunky" and "half the time don't look like they are doing anything" -
traced to four missing pieces of feedback, now fixed across all three and worth holding every future
picker (or any other async-search widget added later) to as a checklist, not just a one-off fix:

1. **Feedback that it's doing something.** The debounce timer used to run for 300ms after every
   keystroke with the "searching" spinner only appearing once the debounced search actually started -
   a dead window that read as unresponsive even though nothing was hung. Fixed: the spinner shows
   from the keystroke itself (see each widget's `_onTextChanged`).
2. **Feedback that it's finished.** The spinner disappearing and either the suggestion list or a
   "no matches" message appearing is the finish signal - already true before this decision, called
   out here so it stays a deliberate property, not an accident of the state machine.
3. **Feedback on what to do next when there are no results.** A bare "No X found" doesn't tell
   someone what to try next. `AircraftPicker`/`AirfieldPicker` (reference data, no create flow) now
   say "check the &lt;spelling/registration&gt; and try again"; `PilotPicker` (which does have a
   create flow) now pairs its existing "Create pilot ..." tile with an explicit "No matches - create
   a new pilot below" helper text, rather than leaving the create option to speak for itself.
4. **A visible, reversible selection.** Once something was picked, the only indicator was a small
   green checkmark, and the only way to search again was to select-all-and-retype the field's text
   by hand - not obvious, and not discoverable. Fixed: the checkmark is now a tappable clear (X)
   button (`Icons.cancel` in `Colors.lightBlue` - green read as a status/success colour rather than
   an actionable one, light blue reads as "tap me" while still being distinct from an error state) that
   clears the field and - for `PilotPicker`/`AirfieldPicker`, which support an empty search - reopens
   the full suggestion list immediately rather than leaving an empty field with nothing to pick until
   something's typed.

### Decision (2026-08-30): cache the Flutter SDK install and skip the wasm dry-run in CI
Two small, independently-verified CI speedups - full numbers and reasoning in
[`docs/ci-performance.md`](ci-performance.md), this is the terse version. `subosito/flutter-action`
was reinstalling the whole Flutter SDK from scratch on every single run (~59s of the build job) with
no caching enabled - added `cache: true`. Separately, `flutter build web --release` runs an advisory
wasm-compatibility dry-run compile by default even though this app has never shipped `--wasm` - added
`--no-wasm-dry-run`, verified locally that `main.dart.js` comes out byte-for-byte identical with or
without it (only an inert placeholder entry in `flutter_bootstrap.js`'s informational build-target
list differs). Confirmed on real CI runs, not just locally: SDK install ~59s -> ~13-21s, the web build
~38s -> ~26-27s.

### Decision (2026-08-30): docs-only commits skip `build` via a conditional job, not a trigger-level path filter
`build.yml` originally considered a trigger-level `paths-ignore` to skip CI for docs-only commits
(mirroring the equivalent fix in `hobbs`'s `build.yml`) - rejected once checked against this repo's
branch protection, which requires the `build` status check. A workflow that never triggers never
posts *any* status, so a required check with no status gets stuck "waiting to be reported" forever
and blocks merging - the opposite of the goal. Fixed instead with a pattern that stays safe alongside
a required check: the workflow always triggers, an unconditional `changes` job detects a genuinely
docs-only commit via `dorny/paths-filter` (`predicate-quantifier: every`, so a commit touching
`README.md` alongside real code still runs the full build), and the expensive `build` job is
conditionally skipped via `if:` based on that output - a job skipped via `if:` still reports
"skipped", which GitHub counts as passing for a required check. Same mechanism used in `hobbs`'s
`build.yml`.

### Decision (2026-08-29): removed the Flutter web service worker
It was flaky (a failed registration only fell back to loading the app after a hard-coded 4-second
timeout) and bought nothing - the web build isn't content-hashed and Caddy already serves it
`Cache-Control: no-cache`, so every load was a fresh fetch regardless of whether a service worker
cached anything. Added a plain CSS loading splash to `web/index.html` instead, so the now-unavoidable
cold JS parse reads as loading rather than broken.

### Decision (2026-08-29): `usePathUrlStrategy()` despite the URL-reset caveat
The alternative (Flutter's default hash-based URLs, `/#/reset-password?...`) wouldn't match
`hobbs`'s actual emailed reset link at all - the backend links to a real path. Accepted the cosmetic
URL-reset quirk (see section 7) rather than building full named-route support for one screen.

### Decision (2026-08-29): hand-rolled `OtpCodeInput` rather than a package dependency
A segmented 6-digit code input is a small, self-contained widget (six controllers + focus nodes).
Matches this project's minimal-dependencies stance (only `http` and `shared_preferences` added
before this) more than pulling in a pub.dev OTP package would.

### Decision (2026-08-29): password-reset UX mirrors `things-ui`'s exactly
Studied `things-ui`'s live implementation directly (one screen, two steps, non-enumerating errors,
auto-login on success) rather than inventing new UX for the same problem `things-ui` had already
solved.

### Decision (2026-08-29): Caddy is not part of this repo
Originally `hobbs-ui` had its own per-repo Caddy compose stack. Moved to a shared
[`caddy`](https://github.com/mojofunk5/caddy) repo once it became clear two frontends on the same VPS
can't each run their own Caddy container bound to host ports 80/443. See that repo and `hobbs`'s own
`docs/DECISIONS.md` for the full reasoning.

## 10. Open work / roadmap

See [`hobbs`'s `docs/ROADMAP.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/ROADMAP.md)
for the full, sequenced, cross-repo picture (shipped / in flight / backlog) - this section is the
short version scoped to this repo. Keep the two in sync.

In rough priority order:

1. **Keep READMEs and architecture docs current, both repos.** *(added 2026-08-31)* A 2026-08-31
   sweep of `hobbs` found six stale plan-doc `Status:` lines and a fully-obsolete `CLAUDE.md` bullet;
   this repo had two stale `Status:` lines of its own (`flight-entry-context-prefetch.md`,
   `split-create-flight-entry-screen.md` - both actually implemented, now fixed). "Update docs in the
   same PR as the change" doesn't self-enforce - treat this as a standing item, not a one-off.
2. **Editing/deleting a flight entry.** Only create/view/list exist - no way to fix a mistyped
   entry or remove one yet.
3. **Photo-to-logbook OCR.** *(expanded 2026-08-31)* Take a photo of a paper logbook page and create
   one or more draft `FlightEntry` rows from it, reviewed/corrected before saving - never
   auto-committed, same precedent as a `FlightTrack`-derived draft entry. Concretely motivated by a
   real, entirely handwritten Pooleys logbook; see `hobbs`'s
   [`docs/reference/pooleys-logbook-notation.jpg`](https://github.com/mojofunk5/hobbs/blob/master/docs/reference/pooleys-logbook-notation.jpg)
   for the exact CAP804 column layout an OCR pass needs to parse, and `hobbs`'s
   [`docs/ROADMAP.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/ROADMAP.md) for the
   full per-column mapping onto the domain, including Holder's Operating Capacity (`hobbs`'s
   [`docs/plans/done/holder-operating-capacity.md`](https://github.com/mojofunk5/hobbs/blob/master/docs/plans/done/holder-operating-capacity.md),
   shipped 2026-08-31), now fully implemented so this item has nothing left it's waiting on.
4. **The iOS app.** This repo is web-only today; iOS (and eventually Android) come from the same
   Flutter codebase.
5. **GPS-recording-to-logbook.** Start a recording, derive a draft `FlightEntry` from the track on
   completion - the MVP-completing feature. Depends on the iOS app existing first (background
   location needs a real mobile platform, not a web tab).
