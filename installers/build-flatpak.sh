#!/bin/bash
set -e

echo "=== Construction du Flatpak ASNUX ==="

FLATPAK_DIR="dist/flatpak/io.asnux.AudioEngine"
mkdir -p "${FLATPAK_DIR}"

cat > "${FLATPAK_DIR}/io.asnux.AudioEngine.yml" << 'FLATPAK_YAML'
app-id: io.asnux.AudioEngine
runtime: org.freedesktop.Platform
runtime-version: '24.08'
sdk: org.freedesktop.Sdk
command: asnux-gui
finish-args:
  - --socket=x11
  - --socket=wayland
  - --share=ipc
  - --device=dri
  - --filesystem=/tmp/asnux-daemon.sock
  - --system-talk-name=org.freedesktop.systemd1

modules:
  - name: asnux
    buildsystem: simple
    build-commands:
      - install -Dm755 asnux-gui /app/bin/asnux-gui
      - install -Dm755 asnux-daemon /app/bin/asnux-daemon
      - install -Dm644 asnux-gui.desktop /app/share/applications/asnux-gui.desktop
      - install -Dm644 asnux.svg /app/share/icons/hicolor/256x256/apps/asnux.svg
    sources:
      - type: file
        path: ../../../target/release/asnux-gui
      - type: file
        path: ../../../target/release/asnux-daemon
      - type: file
        path: ../../../gui/asnux-gui.desktop
      - type: file
        path: ../../../installers/flatpak-icon.svg
        dest-filename: asnux.svg

  - name: asnux-kernel
    buildsystem: simple
    build-commands:
      - install -Dm644 asnux.ko /app/lib/modules/asnux.ko
    sources:
      - type: file
        path: ../../../kernel/asnux.ko
FLATPAK_YAML

# Create Flatpak icon
cat > "flatpak-icon.svg" << 'ICON'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="32" fill="#1a1a2e"/>
  <circle cx="128" cy="128" r="80" fill="none" stroke="#00d4aa" stroke-width="8"/>
  <circle cx="128" cy="128" r="40" fill="none" stroke="#00d4aa" stroke-width="6" stroke-dasharray="10 5"/>
  <circle cx="128" cy="128" r="15" fill="#00d4aa"/>
  <text x="128" y="240" text-anchor="middle" fill="#ffffff" font-family="monospace" font-size="16">ASNUX</text>
</svg>
ICON

cd "${FLATPAK_DIR}"
flatpak-builder build io.asnux.AudioEngine.yml --force-clean
flatpak-builder --repo=repo build io.asnux.AudioEngine.yml
flatpak build-bundle repo ../io.asnux.AudioEngine.flatpak io.asnux.AudioEngine
echo "Flatpak cree: dist/io.asnux.AudioEngine.flatpak"
