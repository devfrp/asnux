#!/bin/bash
set -e

echo "=== Construction du package Solus (eopkg) pour ASNUX ==="

DIST_DIR="dist/solus"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/package.yml" << 'SOLUS_PKG'
name: asnux
version: "1.0.0"
release: 1
source:
  - https://github.com/asnux/asnux/archive/v1.0.0.tar.gz
homepage: https://github.com/asnux/asnux
license: GPL-2.0
description: |
  ASNUX Low-Latency Audio Engine for Linux.
  Equivalent a ASIO4ALL pour Windows.

components:
  - multimedia.sound
  - desktop.core

builddeps:
  - rust
  - cargo
  - linux-headers
  - pkg-config
  - alsa-lib-devel

deps:
  - alsa-lib
  - systemd

setup:
  - tar xf asnux-1.0.0.tar.gz
  - cd asnux-1.0.0

build:
  - cargo build --release --workspace
  - make -C kernel

install:
  - install -Dm755 target/release/asnux-daemon %(installroot)/usr/local/bin/asnux-daemon
  - install -Dm755 target/release/asnux-gui %(installroot)/usr/local/bin/asnux-gui
  - install -Dm644 kernel/asnux.ko %(installroot)/lib/modules/asnux.ko
  - install -Dm644 daemon/asnux-daemon.service %(installroot)/usr/lib/systemd/system/asnux-daemon.service
  - install -Dm644 gui/asnux-gui.desktop %(installroot)/usr/share/applications/asnux-gui.desktop
SOLUS_PKG

echo "Package Solus cree dans ${DIST_DIR}"
echo "  Build: eopkg build-async package.yml"
