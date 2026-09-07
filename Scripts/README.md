
## Testing

```bash
./Scripts/test.sh
```

Unit tests, then end to end against a Docker image built from this working tree.

| Command | What it runs |
|---|---|
| `./Scripts/test.sh` | both |
| `./Scripts/test.sh unit` | `swift test` only |
| `./Scripts/test.sh e2e` | build the image, start it, drive the routes over HTTP |
| `./Scripts/test.sh e2e --no-build` | reuse the image already tagged `install-helper:test` |
| `./Scripts/test.sh e2e --keep` | leave the container up afterwards for manual poking |

The end-to-end run starts the real image with throwaway secrets — your `.env` is never mounted — on port `8099` (`E2E_PORT` to change it), and exits non-zero if anything fails.

Most of its value needs the network. Dropbox answers a dead share link with `200` and an HTML notice page rather than an error status, so the fixtures are real share links whose state is fixed: a deleted build, and a bogus id that gets the "Invalid Link" page. Those checks are skipped, not failed, when Dropbox is unreachable. They also assert the thing that actually broke in production — that a proxied Dropbox page carries none of Dropbox's ~4 KB of headers, which overflow nginx's default 4 KB `proxy_buffer_size` and turn the whole reply into a `502`.

A *working* share link cannot be minted without a real Dropbox upload, so the success cases only run when you point the script at a live build:

```bash
E2E_INSTALL_PATH='/install/scl/fi/<id>/queryparam-rlkey-value-<key>/manifest.plist' \
E2E_APPINFO_PATH='/appinfo/scl/fi/<id>/appinfo.json?rlkey=<key>' ./Scripts/test.sh e2e
```

On macOS the unit tests build with Xcode's Swift rather than the 6.1.3 toolchain pinned in `.swift-version` for the Docker image, which will not build against a newer SDK. Override with `SWIFT_BIN` if needed.

### In CI

`.github/workflows/docker-image.yml` runs the same two layers before anything is published:

1. A `test` job runs `swift test` inside `swift:6.1.3-jammy` — the image the `Dockerfile` builds with, so CI compiles against the pinned toolchain rather than whatever is newest.
2. `build-and-push` waits on it, builds the image into the runner's local daemon, drives `./Scripts/test.sh e2e --no-build` against that image, and only then pushes to GHCR. The push step re-uses the tested layers from cache, so the image that ships is the image that was tested.

A pull request runs both layers but skips the push. If the Dropbox-backed checks ever turn flaky on a runner, set `E2E_SKIP_ONLINE=1` on the end-to-end step — the rest of the suite still gates the push.
