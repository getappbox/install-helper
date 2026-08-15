## AppBox Install Helper

The AppBox backend. One Vapor service, two roles / hostnames:

- **`install.getappbox.com`** — the original install proxies: direct access to Dropbox-hosted files without CORS headers (`/cors`), OTA manifest rewriting (`/install/**`), and appinfo proxies (`/appinfo/scl/**`, `/appinfo/s/**`).
- **`api.getappbox.com`** — the AppBox client API under `/api/v1/*` (config / update check / short links / build emails / notifications). Both hostnames point at the same service; routes are host-agnostic.

## Client API (`/api/v1`)

**Full API reference (all routes, requests/responses, status codes, config): [docs/API.md](docs/API.md).** The summary below is a quick index.

All endpoints require the static client token header `X-AppBox-Client-Token` (env `APPBOX_CLIENT_TOKEN`). `shorten`, `mail/send`, and `notify` additionally require the caller's Dropbox access token as `Authorization: Bearer <token>` — the server verifies it against Dropbox (`users/get_current_account`, cached by token digest for `DROPBOX_TOKEN_CACHE_TTL_SECONDS`), so only real, logged-in AppBox users can send mail, mint short links, or fire notifications.

Errors use `{"error":{"code":"snake_case","message":"…"}}`. Per-IP rate limits: config 120/min, latest-version 120/min, shorten 60/min, mail 20/min, notify 60/min, legacy routes 300/min (in-memory, single instance).

| Endpoint | Auth | Body | Success |
|---|---|---|---|
| `GET /api/v1/config` | client token | — | `{"dropboxAppKey":"…"}` |
| `GET /api/v1/latest-version` | client token | — | `{"version","downloadURL","homebrewVersion"}` |
| `POST /api/v1/shorten` | + Dropbox bearer | `{"url","name","version","build","identifier"}` | `{"shortURL":"https://appbox.me/…"}` |
| `POST /api/v1/mail/send` | + Dropbox bearer | `{"name","version","build","to":[…],"installURL","personalMessage?"}` | `{"id":"<mailgun id>"}` |
| `POST /api/v1/notify` | + Dropbox bearer | `{"service":"slack"|"teams","webhookURL","text"}` | `200` |

Notes:
- `shorten` proxies the appbox.me YOURLS instance and treats a YOURLS **400 that carries `shorturl`** as success — that's how keep-same-link re-uploads keep their stable short URL. A hard failure is `502 shortener_unavailable`; falling back to the long URL is the client's job.
- `mail/send` holds the HTML template server-side; `personalMessage` arrives already rendered (the `{BUILD_*}` placeholder substitution stays client-side).
- `latest-version` merges the GitHub release + Homebrew cask APIs and caches the result (`UPDATE_CACHE_TTL_SECONDS`), so every client's update check doesn't hit GitHub directly (rate limits). The client keeps the version comparison + Homebrew-install detection.
- `notify` owns the Slack/Teams webhook JSON envelope (so it can evolve without an app release); the client sends the already-rendered `text`. The webhook host must be on `NOTIFY_ALLOWED_HOSTS` so the endpoint can't be used as an open relay.
- Dropbox verification outage → `503 verification_unavailable` (fail closed, uncached).

## Configuration

Copy `.env.example` to `.env` and fill in the values (client token, Dropbox app key, Mailgun key/domain, YOURLS secret). A missing `/api/v1` secret is logged at boot but is **not** fatal — the install/appinfo/cors routes keep serving and only the affected `/api/v1` endpoint errors per request. When deploying with docker-compose/systemd, pass the same variables through the environment.

### Memory bounds

Long-running RSS growth (30-40MB at boot creeping to 300-400MB+ over weeks, as seen on pre-1.0.2 deployments) is addressed by four bounds: the `/cors` host allowlist (bounds the HTTP client's per-host connection pools, which are never evicted while the process runs), a `PROXY_MAX_BODY_BYTES` cap on proxied upstream bodies (default 4 MiB; previously up to 4 GiB per request could be buffered), a bounded self-sweeping cache for Dropbox token verdicts (Vapor's memory cache never sweeps expired-but-unread keys), and `MALLOC_ARENA_MAX=2` set in both the Docker image and `installhelper.service` (glibc arena fragmentation otherwise ratchets RSS on multi-core Linux). If you run the binary outside those two paths, export `MALLOC_ARENA_MAX=2` yourself.

## Install Steps

Follow these instruction https://docs.vapor.codes/deploy/digital-ocean/#initial-setup

### Clone (for new install only)
```sh
git clone https://github.com/getappbox/install-helper.git
```

### Change directory
```sh
cd install-helper
```

### Run
```sh
swift run App serve --env production
```

### Create service file
```
/etc/systemd/system/installhelper.service
```

### DNS / hostnames
Point both `install.getappbox.com` and `api.getappbox.com` (A records) at the box; the reverse proxy forwards both vhosts to this service's port and must pass the real client IP as `X-Forwarded-For` (the rate limiter keys on it). Set `TRUSTED_PROXY_COUNT` to the number of proxies in front of the service (default `1`) — the limiter counts that many hops in from the right of the header, since proxies append and everything further left is client-supplied. If the service is reachable directly, set it to `0`.

## Update Steps
### Change user (do not run as root user)
```sh
sudo su vapor
```

### Change directory
```sh
cd install-helper
```

### Fetch latest changes
```sh
git fetch && git pull
```

### Build release app
```sh
swift build -c release
```

### Restart service
```sh
sudo service installhelper restart
```
