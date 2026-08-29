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

Output lands in `build/web/`. In production this is served by Caddy (see `Caddyfile`), which also
reverse-proxies `/api/*` to the backend - so the deployed build uses the default `API_BASE=/api`
(same-origin, no `--dart-define` needed).

## Running the Caddy stack locally

```bash
cp .env.example .env
docker compose up -d
```

Brings up Caddy on `${HTTP_PORT:-80}`/`${HTTPS_PORT:-443}`, serving whatever's symlinked at
`/opt/hobbs-ui/current` (a real deploy artifact - not built by this compose file) and proxying
`/api/*` to `hobbs`'s own compose stack over the shared `hobbs-net` external network.

## Deployment

`.github/workflows/deploy.yml` builds and deploys to the VPS on every push to `master`: `flutter
build web`, SCP the output to `/opt/hobbs-ui/releases/<sha>/` on the VPS, symlink `current` to it,
sync `docker-compose.yml`/`Caddyfile`, reload Caddy. Needs a `VPS_SSH_KEY` repository secret - see
`~/Documents/ClaudeContext/ci-deploy-keys.md` for the generic setup process.
