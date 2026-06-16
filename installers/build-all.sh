#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="${SCRIPT_DIR}/dist"

ALL_BUILDERS=(
    build-deb.sh
    build-rpm.sh
    build-arch.sh
    build-gentoo.sh
    build-alpine.sh
    build-suse.sh
    build-slackware.sh
    build-void.sh
    build-solus.sh
    build-nix.sh
    build-guix.sh
    build-homebrew.sh
    build-clearlinux.sh
    build-tinycore.sh
    build-appimage.sh
    build-flatpak.sh
    build-snap.sh
    build-docker.sh
    build-portable.sh
    build-runfile.sh
)

echo "╔═══════════════════════════════════════════════╗"
echo "║     ASNUX - Build ALL Distributions           ║"
echo "║     20 formats de paquet                      ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# Build Rust binaries
echo "=== [1/3] Construction des binaires Rust ==="
cd "${PROJECT_DIR}"
cargo build --release --workspace
echo ""

# Build kernel module
echo "=== [2/3] Construction du module noyau ==="
make -C kernel
echo ""

# Build all packages
echo "=== [3/3] Construction des packages ==="
mkdir -p "${DIST_DIR}"
TOTAL=${#ALL_BUILDERS[@]}
COUNT=0
SUCCESS=0
FAIL=0

for builder in "${ALL_BUILDERS[@]}"; do
    COUNT=$((COUNT + 1))
    echo ""
    echo "--- [${COUNT}/${TOTAL}] ${builder} ---"

    cd "${SCRIPT_DIR}"
    if bash "${builder}" 2>&1; then
        echo "  OK: ${builder}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  WARN: ${builder} a echoue (dependances manquantes ?)"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  RESULTAT:                                    ║"
echo "║  Reussites: ${SUCCESS}/${TOTAL}                       ║"
echo "║  Echecs:    ${FAIL}/${TOTAL}                       ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "Packages dans: ${DIST_DIR}/"
find "${DIST_DIR}" -type f \( -name "*.deb" -o -name "*.rpm" -o -name "*.pkg.tar.zst" \
    -o -name "*.AppImage" -o -name "*.flatpak" -o -name "*.snap" \
    -o -name "*.txz" -o -name "*.tar.gz" -o -name "*.sh" \) 2>/dev/null | sort
