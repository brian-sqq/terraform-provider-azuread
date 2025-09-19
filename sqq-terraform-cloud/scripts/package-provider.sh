#!/usr/bin/env bash
# Build + package a forked Terraform provider (linux/amd64) for TFC Private Provider Registry.
# Layout:
#   repo root: terraform-provider-azuread/        (Go sources; has go.mod)
#   script:    terraform-provider-azuread/sqq-terraform-cloud/scripts/package-provider.sh
# Outputs go to:
#   terraform-provider-azuread/sqq-terraform-cloud/dist/<VERSION>/
#
# Requires:
#   - arg1: VERSION (e.g., 2.47.0-sqq.1)
#   - env : GPG_KEY_ID (local GPG secret key id/fingerprint)
#
# Produces:
#   dist/<VERSION>/linux_amd64/terraform-provider-azuread_<VERSION>_linux_amd64.zip
#   dist/<VERSION>/SHA256SUMS
#   dist/<VERSION>/SHA256SUMS.asc

set -euo pipefail

# ---- required inputs ----
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <version>   e.g., $0 2.47.0-sqq.1" >&2
  exit 1
fi
VERSION="$1"
: "${GPG_KEY_ID:?GPG_KEY_ID is required (your LOCAL GPG secret key id/fingerprint; see 'gpg --list-secret-keys --keyid-format LONG')}"

# ---- directories (derive from script location) ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"              # .../sqq-terraform-cloud/scripts
CLOUD_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"                              # .../sqq-terraform-cloud
SRC_DIR="${SRC_DIR:-$(cd "${CLOUD_DIR}/.." && pwd)}"                     # .../ (repo root with go.mod)

# ---- build config (override via env if needed) ----
PROVIDER_NAME="${PROVIDER_NAME:-azuread}"
OS="${OS:-linux}"
ARCH="${ARCH:-amd64}"
CGO_ENABLED="${CGO_ENABLED:-0}"

ROOT_DIR="${ROOT_DIR:-${CLOUD_DIR}/dist/${VERSION}}"
OUT_DIR="${OUT_DIR:-${ROOT_DIR}/${OS}_${ARCH}}"
BIN="terraform-provider-${PROVIDER_NAME}_v${VERSION}"
ZIP="terraform-provider-${PROVIDER_NAME}_${VERSION}_${OS}_${ARCH}.zip"
SHA_FILE="${ROOT_DIR}/SHA256SUMS"
SIG_FILE="${ROOT_DIR}/SHA256SUMS.sig"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required tool: $1"; exit 1; }; }
need go; need zip; need gpg
if command -v sha256sum >/dev/null 2>&1; then SHACMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then SHACMD="shasum -a 256"
else echo "Need sha256sum or shasum"; exit 1; fi

[[ -f "${SRC_DIR}/go.mod" ]] || echo "Warning: ${SRC_DIR} has no go.mod; continuing…" >&2

echo "==> Building ${PROVIDER_NAME} ${VERSION} (${OS}/${ARCH})"
echo "    Source: ${SRC_DIR}"
echo "    Output: ${OUT_DIR}"
mkdir -p "${OUT_DIR}" "${ROOT_DIR}"
pushd "${SRC_DIR}" >/dev/null
GOOS="${OS}" GOARCH="${ARCH}" CGO_ENABLED="${CGO_ENABLED}" \
  go build -trimpath -ldflags="-s -w" -o "${OUT_DIR}/${BIN}" .
popd >/dev/null

echo "==> Packaging ${ZIP}"
( cd "${OUT_DIR}" && zip -q -X "${ZIP}" "${BIN}" )

echo "==> Computing SHA256SUMS at ${SHA_FILE}"
[[ -f "${SHA_FILE}" ]] || : > "${SHA_FILE}"
( cd "${OUT_DIR}" && eval ${SHACMD} "\"${ZIP}\"" ) >> "${SHA_FILE}"

echo "==> Signing SHA256SUMS with GPG key ${GPG_KEY_ID}"
gpg --batch --yes --local-user "${GPG_KEY_ID}" --detach-sign --output "${SIG_FILE}" "${SHA_FILE}"

cat <<EOF

✅ Done. Artifacts:
  ${OUT_DIR}/${ZIP}
  ${SHA_FILE}
  ${SIG_FILE}
  
EOF
