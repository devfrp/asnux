#!/bin/bash
set -e

echo "=== Construction du package Alpine Linux (APK) pour ASNUX ==="

DIST_DIR="dist/alpine"
mkdir -p "${DIST_DIR}"/asnux

cat > "${DIST_DIR}/APKBUILD" << 'APKBUILD'
# Maintainer: ASNUX Team <team@asnux.io>
pkgname=asnux
pkgver=1.0.0
pkgrel=0
pkgdesc="ASNUX Low-Latency Audio Engine - Equivalent ASIO4ALL pour Linux"
url="https://github.com/asnux/asnux"
arch="x86_64"
license="GPL-2.0-only"
depends="alsa-lib"
makedepends="cargo rust linux-headers"
install="$pkgname.pre-install $pkgname.post-install $pkgname.pre-deinstall"
source="
    asnux-daemon::../target/release/asnux-daemon
    asnux-gui::../target/release/asnux-gui
    asnux.ko::../kernel/asnux.ko
    asnux-daemon.service::../daemon/asnux-daemon.service
    asnux-gui.desktop::../gui/asnux-gui.desktop
"
sha512sums="
    SKIP
    SKIP
    SKIP
    SKIP
    SKIP
"
options="!check"

build() {
    cd "$srcdir"
    cargo build --release --manifest-path ../Cargo.toml
}

package() {
    install -Dm755 asnux-daemon "$pkgdir/usr/local/bin/asnux-daemon"
    install -Dm755 asnux-gui "$pkgdir/usr/local/bin/asnux-gui"
    install -Dm644 asnux.ko "$pkgdir/lib/modules/asnux.ko"
    install -Dm644 asnux-daemon.service "$pkgdir/etc/init.d/asnux-daemon"
    install -Dm644 asnux-gui.desktop "$pkgdir/usr/share/applications/asnux-gui.desktop"
}
APKBUILD

cat > "${DIST_DIR}/asnux.pre-install" << 'PRE'
#!/bin/sh
# Pre-install: verifier que les kernel headers sont presents
if ! [ -d /lib/modules/$(uname -r) ]; then
    echo "AVERTISSEMENT: Les modules du noyau ne semblent pas installes."
    echo "ASNUX necessite linux-headers pour fonctionner."
fi
exit 0
PRE

cat > "${DIST_DIR}/asnux.post-install" << 'POST'
#!/bin/sh
depmod -a 2>/dev/null || true
echo "ASNUX installe sur Alpine Linux !"
echo "Demarrage: rc-service asnux-daemon start"
echo "Ajouter au demarrage: rc-update add asnux-daemon default"
exit 0
POST

cat > "${DIST_DIR}/asnux.pre-deinstall" << 'PREDE'
#!/bin/sh
rc-service asnux-daemon stop 2>/dev/null || true
modprobe -r asnux 2>/dev/null || true
exit 0
PREDE

chmod +x "${DIST_DIR}"/*.pre-* "${DIST_DIR}"/*.post-*

echo "Package APK cree dans ${DIST_DIR}"
echo "  Build: abuild-keygen -a && abuild -r"
