# AI Working Agreement

This document outlines how AI assistance should behave when working in this codebase. Mirrors
[`things-ui`'s own file](https://github.com/mojofunk5/things-ui/blob/main/docs/ai-working-agreement.md)
in structure and intent, adapted for this stack (Flutter/Dart, not React) and this project's actual
established conventions rather than copied verbatim.

## 1. Match the Existing Code Style

Before writing new code, read the surrounding files to understand the patterns in use - naming
conventions, file structure, widget shape, state management approach. New code should look like it
belongs.

## 2. Work Within Existing Modules, Don't Over-Engineer

Prefer extending existing files over creating new ones. Do not introduce new abstractions, packages,
or layers unless there's a clear and present need - this project is deliberately barebones (see
`architecture-brief.md`'s Non-goals). A hand-rolled solution that avoids a new dependency is
preferred over pulling in a package for something small (see `OtpCodeInput`, hand-rolled rather than
a pub.dev OTP-input package).

## 3. Present a Plan Before Making Non-Trivial Changes

For any change touching more than one file or introducing a new pattern, present a plan first and
wait for approval. Small, obvious fixes (typos, single-line corrections) can proceed without one.

## 4. All API Calls Go Through `lib/api/`

Never call `package:http` directly from a screen. Add a typed method to `AuthApi` (or a new API
class alongside it, following the same shape) instead - see `lib/api/auth_api.dart`.

## 5. Error Handling Is Status-Code-Only, Never a Parsed Body

`hobbs`'s auth endpoints never return a parseable JSON error shape on failure - only a status code,
occasionally plain text. `ApiException` carries just the status code; don't write speculative
JSON-error-parsing code waiting for a shape that doesn't exist. Branch on `e.statusCode` in the
caller, same pattern as every existing screen.

## 6. Business Logic and Validation Live in the Backend

The UI is responsible for presentation and immediate feedback, not business rules. Acceptable on the
client: empty-field checks, a lightweight email-shape sanity check (`ResetPasswordScreen`'s
`_looksLikeEmail`). Not acceptable: reimplementing password-complexity rules, referral-code validity,
or any other check the backend already owns and returns a real error for. If you find yourself
duplicating backend logic client-side, stop and flag it.

## 7. Use `ResponsivePage` for Every Screen's Body

Full-width on phone, a bounded/framed card on wider screens - see `lib/widgets/responsive_page.dart`.
Don't build a new screen with a bare `Center`/`Column` that skips this; it'll look like an
unstyled phone screen stranded on desktop, which is the exact bug this widget was built to fix.

## 8. Changes Must Be Covered by Tests

Every meaningful change needs a test, following the existing patterns:
`http`'s `MockClient` for anything calling the backend, `SharedPreferences.setMockInitialValues({})`
for anything touching `SessionStore`/`RememberedIdentifier`. See `architecture-brief.md`'s Testing
section for the specific gotchas already hit building these.

## 9. Never Push Directly to `master`

Branch protection is live on this repo: a PR is required, the `build` CI check must pass, and
force-push/branch deletion are blocked - this applies even to admins. PRs auto-delete their branch on
merge. Don't auto-merge - open a PR and wait for Andy to review it, even if asked to "raise a PR."

## 10. Record Significant Decisions

A non-obvious architecture choice (a tradeoff weighed, an alternative considered and rejected,
something that departs from an established pattern) gets a dated `### Decision` entry in
`docs/architecture-brief.md`'s Decisions section - see that file for the existing entries and format.
Never delete a decision entry; a later one that supersedes an earlier choice says so explicitly.
