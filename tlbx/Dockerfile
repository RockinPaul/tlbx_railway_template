# tlbx — self-hosted browser terminal multiplexer (https://github.com/tlbx-ai/tlbx)
# Upstream publishes no container image; this installs the signed release binary.
#
# Base is a Node image on purpose: this is a workstation, and the coding agents
# people run inside tlbx (Claude Code, Codex, Gemini CLI, OpenCode) are npm packages.
FROM node:22-bookworm-slim

ARG TLBX_VERSION=v10.16.2
# sha256 of the release tarball itself. The SHA256SUMS.txt inside the archive only
# checks the archive against itself, so it is not a supply-chain check on the download.
ARG TLBX_SHA256_AMD64=20e6f24046d8bdabe8cf4cef717d2d190e0c94f21f32636debb61b000a8a48d2
ARG TLBX_SHA256_ARM64=f5be88265405f63a9b998d2023b43d0aeb5660cadaf5e6c7c10573a87ae4e078
# mise gives the box any toolchain (python, go, rust, another node) without rebuilding
# this image. Its data lives under HOME, which is on the volume, so installs persist.
ARG MISE_VERSION=v2026.9.7
ARG MISE_SHA256_AMD64=6cc34785ae10c38061e569b64b290fc8ac26e94d12c3f1aeb721790fa8f09196
ARG MISE_SHA256_ARM64=d8d38909537af5864822f3ad545d48f1cefae15db266b20052a32da7f834fd50
ARG TARGETARCH

# The tlbx binaries are .NET 10 Native AOT and need only libc and libm. Everything
# installed here is workstation tooling, not a tlbx dependency.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client tmux \
        ripgrep jq less nano procps tini \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) asset="mt-linux-x64.tar.gz";   sha="${TLBX_SHA256_AMD64}" ;; \
        arm64) asset="mt-linux-arm64.tar.gz"; sha="${TLBX_SHA256_ARM64}" ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/tlbx.tar.gz \
        "https://github.com/tlbx-ai/tlbx/releases/download/${TLBX_VERSION}/${asset}"; \
    echo "${sha}  /tmp/tlbx.tar.gz" | sha256sum -c -; \
    mkdir -p /usr/local/lib/tlbx; \
    tar xzf /tmp/tlbx.tar.gz -C /usr/local/lib/tlbx; \
    rm /tmp/tlbx.tar.gz; \
    # the archive ships its own manifest; verify the binaries against it too
    cd /usr/local/lib/tlbx && sha256sum -c SHA256SUMS.txt; \
    ln -s /usr/local/lib/tlbx/mt /usr/local/bin/mt; \
    mt --version

ARG MISE_VERSION
ARG MISE_SHA256_AMD64
ARG MISE_SHA256_ARM64
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) march="x64";   msha="${MISE_SHA256_AMD64}" ;; \
        arm64) march="arm64"; msha="${MISE_SHA256_ARM64}" ;; \
        *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/mise.tar.gz \
        "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-linux-${march}.tar.gz"; \
    echo "${msha}  /tmp/mise.tar.gz" | sha256sum -c -; \
    tar xzf /tmp/mise.tar.gz -C /tmp; \
    mv /tmp/mise/bin/mise /usr/local/bin/mise; \
    rm -rf /tmp/mise /tmp/mise.tar.gz; \
    mise --version

# PORT and the bind address are baked so no service variable can be nulled into a
# required composer field. tlbx serves HTTPS only; Caddy terminates for Railway.
ENV PORT=8080 \
    TLBX_BIND=:: \
    TLBX_SETTINGS_DIR=/data/tlbx \
    HOME=/data/home \
    NPM_CONFIG_PREFIX=/data/npm-global \
    MISE_DATA_DIR=/data/mise \
    MISE_CONFIG_DIR=/data/mise/config \
    MISE_CACHE_DIR=/data/mise/cache \
    MISE_YES=1 \
    PATH=/data/mise/shims:/data/npm-global/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

# A login shell runs /etc/profile, which rebuilds PATH from scratch and discards the
# ENV above. tlbx spawns plain (non-login) bash so its terminals are unaffected, but
# `bash -l` would silently lose the mise shims and npm prefix without this.
RUN printf '%s\n' \
    'case ":$PATH:" in' \
    '  *:/data/mise/shims:*) ;;' \
    '  *) PATH="/data/mise/shims:/data/npm-global/bin:$PATH"; export PATH ;;' \
    'esac' \
    > /etc/profile.d/10-workstation-path.sh

WORKDIR /data/home
EXPOSE 8080

COPY --chmod=755 entrypoint.sh /usr/local/bin/railway-entrypoint
# tini reaps the mthost/mtagenthost subprocess tree; one per terminal session.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/railway-entrypoint"]
