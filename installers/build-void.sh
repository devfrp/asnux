#!/bin/bash
set -e

echo "=== Construction du package Void Linux (xbps) pour ASNUX ==="

DIST_DIR="dist/void"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/template" << 'XBPS_TEMPLATE'
# Template file for 'asnux'
pkgname=asnux
version=1.0.1
revision=1
build_style=cargo
hostmakedepends="rust linux-headers pkg-config"
makedepends="alsa-lib-devel"
depends="alsa-lib"
short_desc="ASNUX Low-Latency Audio Engine for Linux"
maintainer="ASNUX Team <team@asnux.io>"
license="GPL-2.0-only"
homepage="https://github.com/asnux/asnux"
distfiles="https://github.com/asnux/asnux/archive/v${version}.tar.gz"
checksum=0000000000000000000000000000000000000000000000000000000000000000

do_build() {
    cargo build --release --workspace
    make -C kernel
}

do_install() {
    vbin target/release/asnux-daemon
    vbin target/release/asnux-gui

    vinstall kernel/asnux.ko 644 lib/modules

    vinstall daemon/asnux-daemon.service 644 usr/lib/systemd/system
    vinstall gui/asnux-gui.desktop 644 usr/share/applications
}

post_install() {
    depmod -a 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    echo "ASNUX installe sur Void Linux !"
    echo "Demarrage: ln -s /etc/sv/asnux-daemon /var/service/"
}
XBPS_TEMPLATE

# Runit service file for Void
mkdir -p "${DIST_DIR}/runit/log"
cat > "${DIST_DIR}/runit/run" << 'RUN'
#!/bin/sh
exec /usr/local/bin/asnux-daemon 2>&1
RUN
chmod +x "${DIST_DIR}/runit/run"

cat > "${DIST_DIR}/runit/log/run" << 'LOGRUN'
#!/bin/sh
exec vlogger -t asnux-daemon
LOGRUN

echo "Package Void Linux cree dans ${DIST_DIR}"
echo "  Build: xbps-src pkg asnux"
echo "  Runit: copier ${DIST_DIR}/runit/ vers /etc/sv/asnux-daemon"
