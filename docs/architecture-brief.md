# Architecture brief - hobbs-ui

Mirrors [`things-ui`'s own architecture-brief.md](https://github.com/mojofunk5/things-ui/blob/main/docs/architecture-brief.md)
in shape; content is this project's own.

## 1. Purpose

A Flutter client for `hobbs`, a self-hosted PPL flight logbook backend. Today: authentication
(register, login, password reset) plus the create/view/list logbook-entry screens
(`docs/plans/logbook-entries.md` in `hobbs`) - pilot in command/co-pilot are picked via a typeahead
against `GET /pilot?search=` (`docs/plans/pilot-picker.md` in `hobbs`), and aircraft is picked via a
typeahead against `GET /aircraft?search=` (`docs/plans/aircraft-picker.md` in `hobbs`) - plus a
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
   button (`Icons.cancel`, kept green so "you have a valid selection" is still the primary read) that
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

In rough priority order:

1. **Editing/deleting a flight entry.** Only create/view/list exist - no way to fix a mistyped
   entry or remove one yet.
2. **Photo-to-logbook OCR.** Take a picture of a paper logbook page, extract entries from it.
3. **The iOS app.** This repo is web-only today; iOS (and eventually Android) come from the same
   Flutter codebase.
4. **GPS-recording-to-logbook.** Start a recording, derive a draft `FlightEntry` from the track on
   completion - the MVP-completing feature. Depends on the iOS app existing first (background
   location needs a real mobile platform, not a web tab).
