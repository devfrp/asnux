#!/bin/bash
set -e

echo "=== Construction du Snap ASNUX ==="

SNAP_DIR="dist/snap"
mkdir -p "${SNAP_DIR}"

cat > "${SNAP_DIR}/snapcraft.yaml" << 'SNAPCRAFT'
name: asnux
version: '1.0.0'
summary: ASNUX Low-Latency Audio Engine for Linux
description: |
  ASNUX fournit un moteur audio basse latence pour Linux,
  equivalent a ASIO4ALL pour Windows. Inclut un driver
  noyau ALSA virtuel, un daemon systeme, et une interface
  graphique de configuration.

grade: stable
confinement: strict
base: core24

apps:
  asnux-gui:
    command: asnux-gui
    extensions: [gnome]
    plugs:
      - x11
      - wayland
      - unity7
      - audio-playback
      - network
      - system-observe

  asnux-daemon:
    command: asnux-daemon
    daemon: simple
    plugs:
      - system-observe
      - hardware-observe
      - kernel-module-observe

parts:
  asnux:
    plugin: nil
    source: .
    build-packages:
      - cargo
      - rustc
    stage-packages:
      - libasound2
    override-build: |
      cargo build --release
      install -Dm755 target/release/asnux-gui ${SNAPCRAFT_PART_INSTALL}/asnux-gui
      install -Dm755 target/release/asnux-daemon ${SNAPCRAFT_PART_INSTALL}/asnux-daemon
    prime:
      - asnux-gui
      - asnux-daemon

  kernel-module:
    plugin: nil
    source: .
    build-packages:
      - linux-headers-generic
    override-build: |
      make -C kernel
      install -Dm644 kernel/asnux.ko ${SNAPCRAFT_PART_INSTALL}/asnux.ko
    prime:
      - asnux.ko
SNAPCRAFT

cd "${SNAP_DIR}"
export PATH="/snap/bin:$PATH"
snapcraft --destructive-mode
echo "Snap cree: dist/asnux_1.0.0_amd64.snap"
