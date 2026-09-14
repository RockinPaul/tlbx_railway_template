#!/bin/sh
set -eu

SETTINGS_DIR="${TLBX_SETTINGS_DIR:-/data/tlbx}"

# tlbx is fail-closed by design: it refuses to serve control access without a
# password. Refuse earlier and with a clearer message, because on Railway the
# alternative is a container that boots and then locks you out of your own box.
if [ -z "${TLBX_PASSWORD:-}" ]; then
    echo "FATAL: TLBX_PASSWORD is not set." >&2
    echo "  This service is a shell on a public URL. Set TLBX_PASSWORD before deploying." >&2
    exit 1
fi

# Upstream enforces 15-1024 characters. Check it here so the failure is a clear
# log line at boot rather than a rejected --set-password mid-startup.
len=$(printf '%s' "${TLBX_PASSWORD}" | wc -c | tr -d ' ')
if [ "${len}" -lt 15 ]; then
    echo "FATAL: TLBX_PASSWORD is ${len} characters; tlbx requires at least 15." >&2
    exit 1
fi

# Railway mounts the volume root-owned with a lost+found directory, so everything
# lives in subdirectories rather than at the mount point.
mkdir -p "${SETTINGS_DIR}" "${HOME}" "${NPM_CONFIG_PREFIX:-/data/npm-global}" \
         "${MISE_DATA_DIR:-/data/mise}" "${MISE_CONFIG_DIR:-/data/mise/config}" \
         "${MISE_CACHE_DIR:-/data/mise/cache}"

# mise shims are already on PATH, which is enough for non-interactive use. Activation
# additionally applies per-directory .mise.toml environments in interactive shells.
# Seeded once, guarded by a marker, so an edited .bashrc is never clobbered.
if ! grep -q 'mise activate' "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n# added by the Railway entrypoint\neval "$(mise activate bash)"\n' >> "${HOME}/.bashrc"
    echo "tlbx: seeded mise activation into ${HOME}/.bashrc"
fi

# --fingerprint succeeds only when a certificate is already configured, which makes
# it a filename-independent way to ask "do I need to generate one?". The certificate
# lives in the settings directory, so it survives redeploys with the volume.
if ! mt --settings-dir "${SETTINGS_DIR}" --fingerprint >/dev/null 2>&1; then
    echo "tlbx: no certificate yet, generating a self-signed one"
    mt --settings-dir "${SETTINGS_DIR}" --generate-cert
fi

# The Railway variable is the source of truth for the password: it is reapplied on
# every boot, so a password changed in the web UI is reset by the next redeploy.
# Change TLBX_PASSWORD in Railway, not in the UI.
printf '%s\n' "${TLBX_PASSWORD}" | mt --settings-dir "${SETTINGS_DIR}" --set-password >/dev/null
echo "tlbx: password applied from TLBX_PASSWORD"

echo "tlbx: certificate fingerprint $(mt --settings-dir "${SETTINGS_DIR}" --fingerprint 2>/dev/null || echo unknown)"

# tlbx serves HTTPS only and generates its own certificate, so the gateway reaches
# it over HTTPS without verification. Nothing but the gateway can route to it.
exec mt \
    --settings-dir "${SETTINGS_DIR}" \
    --port "${PORT:-8080}" \
    --bind "${TLBX_BIND:-::}" \
    "$@"
