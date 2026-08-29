# hobbs-ui

Flutter web client for [Hobbs](https://github.com/mojofunk5/hobbs), a self-hosted PPL flight
logbook. This first version is a barebones connectivity check - one screen that calls the backend's
`GET /health` and shows the result. Real screens (logbook entries, GPS recording, etc.) come later.

## Running locally

Requires the Hobbs backend running (default: `http://localhost:8080` - see that repo's README).

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

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
