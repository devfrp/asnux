#!/bin/bash
set -e

echo "=== Construction du package Tiny Core Linux (tcz) pour ASNUX ==="

DIST_DIR="dist/tinycore"
mkdir -p "${DIST_DIR}"

# .info file
cat > "${DIST_DIR}/asnux.tcz.info" << 'TCZ_INFO'
Title:          asnux.tcz
Description:    ASNUX Low-Latency Audio Engine for Linux
Version:        1.0.0
Author:         ASNUX Team
Original-site:  https://github.com/asnux/asnux
Copying-policy: GPL
Size:           5M
Extension_by:   ASNUX Team
Tags:           audio, low-latency, ALSA, sound
Comments:       Moteur audio basse latence equivalent a ASIO4ALL
Change-log:     2026/06 - Version initiale
Current:        2026/06/15
TCZ_INFO

# .dep file
cat > "${DIST_DIR}/asnux.tcz.dep" << 'TCZ_DEP'
alsa-lib.tcz
TCZ_DEP

cat > "${DIST_DIR}/asnux.tcz.list" << 'TCZ_LIST'
usr/local/bin/asnux-daemon
usr/local/bin/asnux-gui
usr/local/lib/modules/asnux.ko
usr/local/share/applications/asnux-gui.desktop
TCZ_LIST

echo "Package Tiny Core Linux cree dans ${DIST_DIR}"
echo "  Construction: mksquashfs ${DIST_DIR}/asnux asnux.tcz"
echo "  Installation: tce-load -i asnux.tcz"
