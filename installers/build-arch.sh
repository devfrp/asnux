#!/bin/bash
set -e

echo "=== Construction du package Arch Linux pour ASNUX ==="

PKG_DIR="dist/arch"
mkdir -p "${PKG_DIR}"

# Copy sources into PKGBUILD directory
cp ../target/release/asnux-daemon "${PKG_DIR}/"
cp ../target/release/asnux-gui "${PKG_DIR}/"
cp ../kernel/asnux.ko "${PKG_DIR}/"
cp ../daemon/asnux-daemon.service "${PKG_DIR}/"
cp ../gui/asnux-gui.desktop "${PKG_DIR}/"

cat > "${PKG_DIR}/PKGBUILD" << 'PKGBUILD'
# Maintainer: ASNUX Team <team@asnux.io>
pkgname=asnux
pkgver=1.0.1
pkgrel=1
pkgdesc="ASNUX Low-Latency Audio Engine - Equivalent ASIO4ALL pour Linux"
arch=('x86_64')
license=('GPL2')
depends=('systemd' 'alsa-lib' 'glibc')
makedepends=('linux-headers')
optdepends=('pulseaudio: Moteur audio PulseAudio'
            'pipewire: Moteur audio PipeWire')
install=asnux.install
source=("asnux-daemon"
        "asnux-gui"
        "asnux.ko"
        "asnux-daemon.service"
        "asnux-gui.desktop")
sha256sums=('SKIP'
            'SKIP'
            'SKIP'
            'SKIP'
            'SKIP')

package() {
    install -Dm755 "${srcdir}/asnux-daemon" "${pkgdir}/usr/local/bin/asnux-daemon"
    install -Dm755 "${srcdir}/asnux-gui" "${pkgdir}/usr/local/bin/asnux-gui"
    install -Dm644 "${srcdir}/asnux.ko" "${pkgdir}/usr/local/lib/modules/asnux.ko"
    install -Dm644 "${srcdir}/asnux-daemon.service" "${pkgdir}/usr/lib/systemd/system/asnux-daemon.service"
    install -Dm644 "${srcdir}/asnux-gui.desktop" "${pkgdir}/usr/share/applications/asnux-gui.desktop"
}
PKGBUILD

cat > "${PKG_DIR}/asnux.install" << 'INSTALL'
post_install() {
    KVER=$(uname -r)
    mkdir -p "/lib/modules/${KVER}/extra"
    cp /usr/local/lib/modules/asnux.ko "/lib/modules/${KVER}/extra/asnux.ko" 2>/dev/null || true
    depmod -a 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable asnux-daemon 2>/dev/null || true
    systemctl start asnux-daemon 2>/dev/null || true
    echo "ASNUX installe et daemon demarre !"
}

pre_remove() {
    systemctl stop asnux-daemon 2>/dev/null || true
    systemctl disable asnux-daemon 2>/dev/null || true
    modprobe -r asnux 2>/dev/null || true
}

post_remove() {
    depmod -a 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
}
INSTALL

cd "${PKG_DIR}"
if command -v makepkg &>/dev/null; then
    makepkg -cf
    mv *.pkg.tar.zst ../
    echo "Package Arch Linux cree"
else
    echo "makepkg not available (not on Arch), assembling package manually"

    STAGING="../.arch-staging"
    rm -rf "${STAGING}"
    mkdir -p "${STAGING}/usr/local/bin" \
             "${STAGING}/usr/local/lib/modules" \
             "${STAGING}/usr/lib/systemd/system" \
             "${STAGING}/usr/share/applications"

    install -Dm755 asnux-daemon "${STAGING}/usr/local/bin/asnux-daemon"
    install -Dm755 asnux-gui "${STAGING}/usr/local/bin/asnux-gui"
    install -Dm644 asnux.ko "${STAGING}/usr/local/lib/modules/asnux.ko"
    install -Dm644 asnux-daemon.service "${STAGING}/usr/lib/systemd/system/asnux-daemon.service"
    install -Dm644 asnux-gui.desktop "${STAGING}/usr/share/applications/asnux-gui.desktop"

    cat > "${STAGING}/.PKGINFO" << PKGINFO
pkgname = asnux
pkgver = 1.0.1-1
pkgdesc = ASNUX Low-Latency Audio Engine - Equivalent ASIO4ALL pour Linux
url = https://asnux.io
builddate = $(date -u +%s)
packager = ASNUX Team <team@asnux.io>
size = $(du -sb "${STAGING}/usr" | cut -f1)
arch = x86_64
license = GPL2
depend = systemd
depend = alsa-lib
depend = glibc
optdepend = pulseaudio: Moteur audio PulseAudio
optdepend = pipewire: Moteur audio PipeWire
PKGINFO

    cp asnux.install "${STAGING}/.INSTALL"

    if command -v bsdtar &>/dev/null; then
        (cd "${STAGING}" && bsdtar --format=mtree --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' usr > "../.MTREE")
        mv "../.MTREE" "${STAGING}/.MTREE"
    fi

    PKG_NAME="asnux-1.0.1-1-x86_64.pkg.tar.gz"
    if [ -f "${STAGING}/.MTREE" ]; then
        tar czf "../${PKG_NAME}" -C "${STAGING}" .PKGINFO .INSTALL .MTREE usr
    else
        tar czf "../${PKG_NAME}" -C "${STAGING}" .PKGINFO .INSTALL usr
    fi
    rm -rf "${STAGING}"
    echo "Package Arch Linux cree: ${PKG_NAME}"
fi
