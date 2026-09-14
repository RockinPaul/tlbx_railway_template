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

# PORT and the bind address are baked so no service variable can be nulled into a
# required composer field. tlbx serves HTTPS only; Caddy terminates for Railway.
ENV PORT=8080 \
    TLBX_BIND=:: \
    TLBX_SETTINGS_DIR=/data/tlbx \
    HOME=/data/home \
    NPM_CONFIG_PREFIX=/data/npm-global \
    PATH=/data/npm-global/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin

WORKDIR /data/home
EXPOSE 8080

COPY --chmod=755 entrypoint.sh /usr/local/bin/railway-entrypoint
# tini reaps the mthost/mtagenthost subprocess tree; one per terminal session.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/railway-entrypoint"]
