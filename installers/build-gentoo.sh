#!/bin/bash
set -e

echo "=== Construction du package Gentoo/ebuild pour ASNUX ==="

DIST_DIR="dist/gentoo"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/asnux-1.0.1.ebuild" << 'EBUILD'
# Copyright 2026 ASNUX Team
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod rust-toolchain

DESCRIPTION="ASNUX Low-Latency Audio Engine - Equivalent ASIO4ALL pour Linux"
HOMEPAGE="https://github.com/asnux/asnux"
SRC_URI="https://github.com/asnux/asnux/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
IUSE="pulseaudio pipewire"

RDEPEND="
    acct-group/audio
    pulseaudio? ( media-sound/pulseaudio )
    pipewire? ( media-video/pipewire )
    sys-apps/systemd
"
DEPEND="${RDEPEND}
    virtual/linux-sources
    sys-kernel/linux-headers
"

MODULE_NAMES="asnux(misc:${S}/kernel)"

src_compile() {
    cargo_src_compile --workspace
    linux-mod_src_compile
}

src_install() {
    cargo_src_install --path daemon --root "${D}/usr"
    cargo_src_install --path gui --root "${D}/usr"
    linux-mod_src_install

    insinto /usr/lib/systemd/system
    doins "${S}/daemon/asnux-daemon.service"

    insinto /usr/share/applications
    doins "${S}/gui/asnux-gui.desktop"
}

pkg_postinst() {
    linux-mod_pkg_postinst
    systemctl daemon-reload
    systemctl enable asnux-daemon 2>/dev/null || true
    systemctl start asnux-daemon 2>/dev/null || true
    elog "ASNUX installee et daemon demarre !"
}

pkg_prerm() {
    systemctl stop asnux-daemon 2>/dev/null || true
    systemctl disable asnux-daemon 2>/dev/null || true
    modprobe -r asnux 2>/dev/null || true
}
EBUILD

# Generate manifest
cat > "${DIST_DIR}/Manifest" << 'MANIFEST'
DIST asnux-1.0.1.tar.gz 0 BLAKE2B 00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
MANIFEST

echo "Package Gentoo cree: ${DIST_DIR}/asnux-1.0.1.ebuild"
echo "  Installation: sudo cp ${DIST_DIR}/asnux-1.0.1.ebuild /usr/local/portage/media-sound/asnux/"
echo "  puis: sudo emerge asnux"
