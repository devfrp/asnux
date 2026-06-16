#!/bin/bash
set -e

echo "=== Construction du bundle Clear Linux pour ASNUX ==="

DIST_DIR="dist/clearlinux"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/asnux.spec" << 'CLEAR_SPEC'
# Clear Linux OS bundle for ASNUX
name: asnux
version: "1.0.0"
description: |
  ASNUX Low-Latency Audio Engine for Linux
  Bundle Clear Linux pour le moteur audio basse latence ASNUX

dependencies:
  - alsa-lib
  - systemd

packages:
  - binary: asnux-daemon
    path: /usr/local/bin/asnux-daemon
  - binary: asnux-gui
    path: /usr/local/bin/asnux-gui
  - library: asnux.ko
    path: /lib/modules
  - unit: asnux-daemon.service
    path: /usr/lib/systemd/system
  - desktop: asnux-gui.desktop
    path: /usr/share/applications
CLEAR_SPEC

echo "Bundle Clear Linux cree dans ${DIST_DIR}"
echo "  Build: swupd bundle-create asnux-bundle"
