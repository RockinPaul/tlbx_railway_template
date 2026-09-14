# Deploy and Host tlbx on Railway

[tlbx](https://github.com/tlbx-ai/tlbx) is a self-hosted terminal multiplexer you reach from a
browser: persistent shells, a file and Git view, and dedicated sessions for coding agents like
Claude Code, Codex, Gemini CLI and OpenCode. This template runs it as a workstation you can open
from a laptop, a tablet or a phone.

## About Hosting tlbx

tlbx expects to run on a machine you own, and it has no HTTP mode at all — it serves HTTPS with a
certificate it generates for itself. Railway's edge speaks plain HTTP to a container, so this
template puts a small gateway in front: the gateway is the only service reachable from the internet,
it answers the platform health check itself, and it forwards to tlbx over HTTPS on the private
network. Getting the forwarded headers wrong here produces a deployment that looks perfect and does
not work, so the gateway configuration is the substance of this template.

The login password is generated for you rather than typed into a deploy form, and a volume keeps
your home directory, your repositories and your installed toolchains across redeploys.

## Common Use Cases

- Keep a long-running coding agent working in a box you can check on from your phone.
- Use a real terminal and a Git view from a tablet, or from a machine you would rather not install a
  toolchain on.
- Give a project a persistent home with its own toolchain, separate from your laptop.

## Dependencies for tlbx Hosting

- A volume for the workstation, which the template creates.
- Nothing else. There is no database, no external service, and no account to register.

### Deployment Dependencies

- [tlbx](https://github.com/tlbx-ai/tlbx) — the upstream project (AGPL-3.0-or-later, with commercial
  licensing available).
- [Caddy](https://caddyserver.com) — the gateway (Apache-2.0).
- [mise](https://mise.jdx.dev) — installs language toolchains onto the volume (MIT).

### Implementation Details

Two services build from this template's repository, each from its own directory:

- **caddy** — the only public service. It answers the platform health check on its own, then
  forwards everything to tlbx over HTTPS with verification skipped, because tlbx's certificate is
  self-signed and the hop never leaves Railway's private network. It passes the client's Host
  through verbatim: tlbx compares the browser's Origin against that Host on scheme, host and port,
  so a rewritten Host makes every WebSocket the interface opens fail while the page still loads.
- **tlbx** — the server and your shells, built on a Node base image because the coding agents people
  run inside tlbx are npm packages. The upstream project publishes no container image, so the
  template installs the signed release binary and checks it against a pinned digest. Your home
  directory, npm global prefix and mise data all live on the volume.

The password is generated with a Railway secret, so there is nothing to fill in. Read it from the
tlbx service's variables, then open the gateway's URL and sign in. Installing a toolchain with
`mise use -g python@3.13` puts it on the volume, so it survives redeploys; the image itself ships
only Node.

Three limits are worth knowing before you deploy. Running sessions end when the service redeploys,
because a redeploy replaces the host — files on the volume survive, shells do not. The upstream app
preview feature cannot work here, because it serves previews from a second port and tells the
browser to fetch them from a URL Railway's edge does not answer. And Railway containers are not
privileged, so nothing inside can build or run containers.

## Why Deploy tlbx on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your
infrastructure so you don't have to deal with configuration, while allowing you to vertically and
horizontally scale it.

By deploying tlbx on Railway, you are one step closer to supporting a complete full-stack
application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
