# tlbx on Railway

A browser-reachable workstation: [tlbx](https://github.com/tlbx-ai/tlbx) — persistent shells and
coding-agent sessions in a browser — behind a Caddy gateway, with a volume that keeps your home
directory, repositories and tool installs across redeploys.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/tlbx)

## Services

| Service | Image | Public | Role |
|---|---|---|---|
| `caddy` | `caddy:2.11-alpine` | **yes** | The only way in. Terminates Railway's plain HTTP and proxies to tlbx over HTTPS. |
| `tlbx` | `node:22-bookworm-slim` + pinned `mt` binary | no | The server, your shells, and the volume at `/data`. |

Upstream publishes no container image, so `tlbx/Dockerfile` installs the signed release binary and
verifies it against a pinned sha256. The base is a Node image on purpose: the coding agents people
run inside tlbx (Claude Code, Codex, Gemini CLI, OpenCode) are npm packages.

## Variables

| Service | Variable | Default | Purpose |
|---|---|---|---|
| `tlbx` | `TLBX_PASSWORD` | generated (48 chars) | Login password. Read it from this service's variables after deploying. At least 15 characters — tlbx's own minimum — and the container refuses to start without it. |
| `tlbx` | `PORT` | `8080` | Baked into the image. |
| `tlbx` | `TLBX_BIND` | `::` | Baked. Dual-stack, for Railway's IPv6 private network. |
| `tlbx` | `TLBX_SETTINGS_DIR` | `/data/tlbx` | Baked. All state — settings, secrets, certificate — lives here. |
| `tlbx` | `HOME` | `/data/home` | Baked. Your shell home, on the volume. |
| `tlbx` | `NPM_CONFIG_PREFIX` | `/data/npm-global` | Baked. `npm i -g` survives redeploys. |
| `tlbx` | `MISE_DATA_DIR` | `/data/mise` | Baked. Toolchains installed with mise survive redeploys. |

The template asks for nothing: `TLBX_PASSWORD` is generated with `${{secret(48)}}`, which is both
zero-input and stronger than anything a deploy form would coax out of someone. Read it from the
`tlbx` service's variables to sign in.

`TLBX_PASSWORD` is reapplied on every boot, so it is the single source of truth. A password changed
in the web UI is reset by the next redeploy — change it in Railway instead.

## What persists

The volume is mounted at `/data` and holds three things that make this a workstation rather than a
scratch container:

- `/data/home` — your shell home: repositories, dotfiles, SSH keys, agent configuration.
- `/data/npm-global` — globally installed npm packages, so `npm i -g @anthropic-ai/claude-code`
  survives a redeploy.
- `/data/mise` — toolchains installed with [mise](https://mise.jdx.dev). The image ships Node only;
  `mise use -g python@3.13` (or go, rust, a different node) gets you the rest without rebuilding it,
  and the shims directory is already on `PATH`.
- `/data/tlbx` — tlbx's own settings, secrets and self-signed certificate.

**Sessions do not persist.** Files survive a redeploy; running shells and agent sessions do not.
tlbx keeps sessions alive while its host stays awake, and a Railway redeploy replaces the host.

## Why it is shaped this way

Four things drive the configuration, and three of them produce a deployment that looks fine and is
not:

- **tlbx serves HTTPS only.** `app.Urls.Add($"https://{bind}:{port}")` is hardcoded; there is no
  HTTP mode. Railway's edge speaks plain HTTP to a container, so Caddy sits in front, answers the
  platform health check itself on `/up`, and dials tlbx over HTTPS with verification skipped — the
  certificate is self-signed and the hop never leaves Railway's private network.
- **The browser's `Origin` must match the `Host` tlbx receives.** `RequestOriginPolicy.cs` compares
  scheme, host **and** port against `request.Host`, and Caddy's TLS transport rewrites `Host` to the
  upstream address. Left alone, every WebSocket the UI opens returns 403 and the editor loads but
  never connects. `header_up Host {http.request.hostport}` restores the client's host verbatim.
  Use `{http.request.hostport}`, not `{host}` — the latter drops the port.
- **`X-Forwarded-Proto: https` is required.** TLS ends at Railway's edge, so without it tlbx hands
  the browser `ws://` URLs that an `https` page refuses as mixed content.
- **The volume arrives root-owned with a `lost+found`.** Everything lives in subdirectories, created
  by the entrypoint, never at the mount root.

## What does not work here

Two upstream features do not survive the move to Railway. Both are platform limits, not bugs:

- **App preview.** tlbx serves previews from a second listener on `PORT + 1` and tells the browser
  to fetch them from `scheme://<the host you used>:8081` — `previewPort = mainPort + 1` in
  `BrowserPreviewOriginService.Create`, with no setting to override the origin. Railway's edge only
  answers on 443, so that URL can never resolve. To look at a dev server running in the box, add an
  explicit route for it to the Caddyfile.
- **Docker inside the box.** Railway containers are not privileged, so agents that want to build or
  run containers cannot. Everything else in a normal toolchain works.

## Security

This service is a shell on a public URL. Treat it accordingly.

tlbx itself is fail-closed and unusually strict, which is the main reason this was worth building:
HTTPS and a password are mandatory and cannot be disabled, passwords are 15–1024 characters hashed
with PBKDF2-HMAC-SHA256 at 600,000 iterations, failed attempts trigger accumulating lockouts, and
browser mutations and WebSocket handshakes are same-origin checked. The entrypoint refuses to start
without `TLBX_PASSWORD`, and refuses a password under 15 characters.

Upstream scopes remote access to a trusted LAN or a private VPN. A Railway domain is neither. Use a
long generated password, and prefer Railway's private networking or a VPN if you can.

## First run

1. Copy `TLBX_PASSWORD` from the `tlbx` service's variables — it was generated for you.
2. Open the `caddy` service's URL and sign in.
3. The browser will trust Railway's certificate, not tlbx's. The fingerprint-verification workflow
   in upstream's documentation (`mt --fingerprint`) applies to a direct connection, not to this one:
   here the gateway is the trust boundary.
4. To install an agent: open a terminal and `npm i -g` it. It lands in `/data/npm-global` and
   survives redeploys.

## Upgrading tlbx

Bump `TLBX_VERSION` in `tlbx/Dockerfile` **and** the matching `TLBX_SHA256_*` digests, then push.

Upstream releases several times a day and marks most of them prerelease; pin a stable tag. At the
time of writing that is `v10.16.2`, and only five of the last hundred releases were stable.

## Files

```
tlbx/Dockerfile      pinned release binary + mise, both verified by sha256, on a Node base
tlbx/entrypoint.sh   refuses a missing or short password, seeds cert and password, execs mt
tlbx/railway.json    watch patterns, single replica
caddy/Caddyfile      health endpoint, HTTPS upstream, Host and X-Forwarded-Proto handling
caddy/Dockerfile     caddy:2.11-alpine
caddy/railway.json   watch patterns, /up health check
```

## Licences

tlbx is [AGPL-3.0](https://github.com/tlbx-ai/tlbx/blob/main/LICENSE) and offers commercial
licensing. Caddy is Apache-2.0. The glue in this repository is MIT.
