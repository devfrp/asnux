#!/bin/bash
set -e

echo "=== Construction du package DEB pour ASNUX ==="

DIST_DIR="dist/deb"
mkdir -p "${DIST_DIR}"/DEBIAN
mkdir -p "${DIST_DIR}"/usr/local/bin
mkdir -p "${DIST_DIR}"/usr/local/lib/modules
mkdir -p "${DIST_DIR}"/usr/share/applications
mkdir -p "${DIST_DIR}"/usr/share/icons/hicolor/256x256/apps
mkdir -p "${DIST_DIR}"/lib/systemd/system

cat > "${DIST_DIR}/DEBIAN/control" << 'CONTROL'
Package: asnux
Version: 1.0.0
Section: sound
Priority: optional
Architecture: amd64
Depends: systemd, libc6 (>= 2.31)
Recommends: pulseaudio, pipewire
Maintainer: ASNUX Team <team@asnux.io>
Description: ASNUX Low-Latency Audio Engine for Linux
 ASNUX fournit un moteur audio basse latence pour Linux,
 equivalent a ASIO4ALL pour Windows.
 .
 Features:
  - Driver noyau ALSA virtuel basse latence
  - GUI de configuration (buffer, sample rate, canaux)
  - Moteur audio systeme par defaut configurable
  - Priorite temps reel pour les flux audio
CONTROL

cat > "${DIST_DIR}/DEBIAN/postinst" << 'POSTINST'
#!/bin/bash
set -e
echo "Configuration d'ASNUX..."
KVER=$(uname -r)
mkdir -p "/lib/modules/${KVER}/extra"
cp /usr/local/lib/modules/asnux.ko "/lib/modules/${KVER}/extra/asnux.ko" 2>/dev/null || true
depmod -a 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
systemctl enable asnux-daemon 2>/dev/null || true
systemctl start asnux-daemon 2>/dev/null || true
echo "ASNUX installe et daemon demarre !"
exit 0
POSTINST
chmod +x "${DIST_DIR}/DEBIAN/postinst"

cat > "${DIST_DIR}/DEBIAN/prerm" << 'PRERM'
#!/bin/bash
set -e
systemctl stop asnux-daemon 2>/dev/null || true
modprobe -r asnux 2>/dev/null || true
exit 0
PRERM
chmod +x "${DIST_DIR}/DEBIAN/prerm"

cp ../target/release/asnux-daemon "${DIST_DIR}/usr/local/bin/"
cp ../target/release/asnux-gui "${DIST_DIR}/usr/local/bin/"
if [ -f ../kernel/asnux.ko ]; then
    cp ../kernel/asnux.ko "${DIST_DIR}/usr/local/lib/modules/"
else
    echo "Kernel module not found, skipping"
fi
cp ../gui/asnux-gui.desktop "${DIST_DIR}/usr/share/applications/"
cp ../daemon/asnux-daemon.service "${DIST_DIR}/lib/systemd/system/"

DEB_NAME="asnux-1.0.0-amd64.deb"

cd "${DIST_DIR}"
echo "2.0" > debian-binary

cd DEBIAN && tar czf ../control.tar.gz . && cd ..
tar cJf data.tar.xz usr lib

ar rcs "${DEB_NAME}" debian-binary control.tar.gz data.tar.xz
cd ..

echo "Package DEB cree: ${DIST_DIR}/${DEB_NAME}"
