#!/bin/bash
set -e

echo "=== Construction du tarball portable ASNUX ==="

DIST_DIR="dist/portable"
TARBALL_DIR="asnux-1.0.0-linux-x86_64"

mkdir -p "${DIST_DIR}/${TARBALL_DIR}"/{bin,lib,share}

# Binaires
cp ../target/release/asnux-daemon "${DIST_DIR}/${TARBALL_DIR}/bin/"
cp ../target/release/asnux-gui "${DIST_DIR}/${TARBALL_DIR}/bin/"
strip "${DIST_DIR}/${TARBALL_DIR}/bin/"*

# Scripts
cat > "${DIST_DIR}/${TARBALL_DIR}/install.sh" << 'INSTALL'
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${1:-/usr/local}"

echo "Installation d'ASNUX..."
echo "Prefixe: ${PREFIX}"

install -Dm755 "${SCRIPT_DIR}/bin/asnux-daemon" "${PREFIX}/bin/asnux-daemon"
install -Dm755 "${SCRIPT_DIR}/bin/asnux-gui" "${PREFIX}/bin/asnux-gui"

install -Dm644 "${SCRIPT_DIR}/share/asnux-daemon.service" \
    "${PREFIX}/lib/systemd/system/asnux-daemon.service"
install -Dm644 "${SCRIPT_DIR}/share/asnux-gui.desktop" \
    "${PREFIX}/share/applications/asnux-gui.desktop"

# Module noyau
if [ -f "${SCRIPT_DIR}/lib/asnux.ko" ]; then
    KERNEL_DIR="/lib/modules/$(uname -r)"
    if [ -d "${KERNEL_DIR}" ]; then
        install -Dm644 "${SCRIPT_DIR}/lib/asnux.ko" \
            "${KERNEL_DIR}/kernel/drivers/sound/asnux.ko"
        depmod -a
    fi
fi

systemctl daemon-reload 2>/dev/null || true
systemctl enable asnux-daemon 2>/dev/null || true
systemctl start asnux-daemon 2>/dev/null || true

echo "ASNUX installe dans ${PREFIX}"
echo "Daemon demarre et active au demarrage !"
echo "GUI: asnux-gui"
INSTALL

cat > "${DIST_DIR}/${TARBALL_DIR}/uninstall.sh" << 'UNINSTALL'
#!/bin/bash
set -e

PREFIX="${1:-/usr/local}"

systemctl stop asnux-daemon 2>/dev/null || true
systemctl disable asnux-daemon 2>/dev/null || true
modprobe -r asnux 2>/dev/null || true

rm -f "${PREFIX}/bin/asnux-daemon"
rm -f "${PREFIX}/bin/asnux-gui"
rm -f "${PREFIX}/lib/systemd/system/asnux-daemon.service"
rm -f "${PREFIX}/share/applications/asnux-gui.desktop"
rm -f "/lib/modules/$(uname -r)/kernel/drivers/sound/asnux.ko"

systemctl daemon-reload 2>/dev/null || true
depmod -a 2>/dev/null || true

echo "ASNUX desinstalle de ${PREFIX}"
UNINSTALL

chmod +x "${DIST_DIR}/${TARBALL_DIR}/install.sh"
chmod +x "${DIST_DIR}/${TARBALL_DIR}/uninstall.sh"

# Service file
cp ../daemon/asnux-daemon.service "${DIST_DIR}/${TARBALL_DIR}/share/"
cp ../gui/asnux-gui.desktop "${DIST_DIR}/${TARBALL_DIR}/share/"

# Kernel module
cp ../kernel/asnux.ko "${DIST_DIR}/${TARBALL_DIR}/lib/"

# README
cat > "${DIST_DIR}/${TARBALL_DIR}/README.txt" << 'README'
ASNUX v1.0.0 - Portable Linux Binary
=====================================

Installation:
  sudo ./install.sh [prefix]
  (default prefix: /usr/local)

Desinstallation:
  sudo ./uninstall.sh [prefix]

Utilisation:
  1. asnux-daemon (demarrer le daemon)
  2. asnux-gui   (interface graphique)

Site: https://github.com/asnux/asnux
README

# Création du tarball
cd "${DIST_DIR}"
tar czf "asnux-1.0.0-linux-x86_64.tar.gz" "${TARBALL_DIR}"
echo "Tarball cree: dist/portable/asnux-1.0.0-linux-x86_64.tar.gz"

# SHA256
sha256sum "asnux-1.0.0-linux-x86_64.tar.gz" > "asnux-1.0.0-linux-x86_64.tar.gz.sha256"
echo "SHA256: $(cat asnux-1.0.0-linux-x86_64.tar.gz.sha256)"
