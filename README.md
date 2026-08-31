# hobbs-ui

Flutter web client for [Hobbs](https://github.com/mojofunk5/hobbs), a self-hosted PPL flight
logbook. Live at [hobbs.bssd.co.uk](https://hobbs.bssd.co.uk).

## What's here today

- **Welcome** - plane icon, Log in / Register
- **Register** / **Log in** (with a "Remember my email" checkbox)
- **Reset password** - request a code by email, then confirm with the 6-digit code and a new
  password. Deep-linkable from the actual emailed reset link
  (`hobbs.bssd.co.uk/reset-password?email=&code=`) straight into a locked, pre-filled confirm step
- **Signed in** - landing screen with links into the logbook screens below
- **Log a flight** - the CAP804/FCL.050 entry form (`POST /flight`). Pilot in command/co-pilot are
  picked via a typeahead against `GET /pilot?search=` (PIC defaults to yourself), with an inline
  "create new pilot" fallback - see
  [hobbs's docs/plans/done/pilot-picker.md](https://github.com/mojofunk5/hobbs/blob/master/docs/plans/done/pilot-picker.md).
  Aircraft is picked via a typeahead against `GET /aircraft?search=` - no "create new" fallback,
  since aircraft is reference data seeded from OpenSky, not pilot-submitted - see
  [hobbs's docs/plans/done/aircraft-picker.md](https://github.com/mojofunk5/hobbs/blob/master/docs/plans/done/aircraft-picker.md)
- **Your flights** - lists every entry for the signed-in pilot (`GET /flight`, no pagination yet),
  each row opening the view screen below
- **View a flight** - looks up one entry by id (`GET /flight/{id}`); reachable directly (paste an
  id) or via "Your flights" / straight after creating one
- **Browse aircraft** - search-first view over the same `GET /aircraft?search=` reference data
  (registration/make/model/owner/operator/built/engines/serial number), not scoped to the
  flight-entry form

See `docs/architecture-brief.md` for how this is put together, and its Open Work section for what's
next.

## Running locally

Requires the Hobbs backend running (default: `http://localhost:8080` - see that repo's README).

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

## Running tests

```bash
flutter analyze
flutter test
```

See `docs/architecture-brief.md`'s Testing section for the `MockClient`/`SharedPreferences` mocking
patterns used throughout.

## Building for production

```bash
flutter build web --release
```

Output lands in `build/web/`. In production this is served by the shared
[`caddy`](https://github.com/mojofunk5/caddy) repo's reverse proxy, which also proxies `/api/*` to
the backend - so the deployed build uses the default `API_BASE=/api` (same-origin, no
`--dart-define` needed). Caddy isn't part of this repo - see `caddy` for why (two frontends can't
each run their own Caddy container bound to host ports 80/443).

## Deployment

`.github/workflows/deploy.yml` builds and deploys to the VPS on every push to `master`: `flutter
build web`, SCP the output to `/opt/hobbs-ui/releases/<sha>/` on the VPS, symlink `current` to it.
The shared Caddy instance (see `caddy` repo) reads through that symlink on every request, so no
reload is needed here. Needs a `VPS_SSH_KEY` repository secret - see
`~/Documents/ClaudeContext/ci-deploy-keys.md` for the generic setup process.
