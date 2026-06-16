#!/bin/bash
set -e

echo "=== Construction de l'AppImage ASNUX ==="

APP_DIR="dist/AppImage/ASNUX.AppDir"
mkdir -p "${APP_DIR}/usr/local/bin"
mkdir -p "${APP_DIR}/usr/share/applications"
mkdir -p "${APP_DIR}/usr/share/icons/hicolor/256x256/apps"

cp ../target/release/asnux-gui "${APP_DIR}/usr/local/bin/"
cp ../gui/asnux-gui.desktop "${APP_DIR}/usr/share/applications/"

cat > "${APP_DIR}/AppRun" << 'APPRUN'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/local/bin/:${HERE}/usr/bin/:${HERE}/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib/:${HERE}/lib:${LD_LIBRARY_PATH}"
exec asnux-gui "$@"
APPRUN
chmod +x "${APP_DIR}/AppRun"

cat > "${APP_DIR}/asnux.desktop" << 'DESKTOP'
[Desktop Entry]
Name=ASNUX Audio Engine
Comment=Low-latency audio engine configuration for Linux
Exec=asnux-gui
Icon=asnux
Terminal=false
Type=Application
Categories=Audio;AudioVideo;Settings;
DESKTOP

# Generate icon (simple SVG as placeholder)
cat > "${APP_DIR}/usr/share/icons/hicolor/256x256/apps/asnux.svg" << 'ICON'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="32" fill="#1a1a2e"/>
  <circle cx="128" cy="128" r="80" fill="none" stroke="#00d4aa" stroke-width="8"/>
  <circle cx="128" cy="128" r="40" fill="none" stroke="#00d4aa" stroke-width="6" stroke-dasharray="10 5"/>
  <circle cx="128" cy="128" r="15" fill="#00d4aa"/>
  <line x1="128" y1="48" x2="128" y2="78" stroke="#00d4aa" stroke-width="4" stroke-linecap="round"/>
  <line x1="128" y1="178" x2="128" y2="208" stroke="#00d4aa" stroke-width="4" stroke-linecap="round"/>
  <line x1="48" y1="128" x2="78" y2="128" stroke="#00d4aa" stroke-width="4" stroke-linecap="round"/>
  <line x1="178" y1="128" x2="208" y2="128" stroke="#00d4aa" stroke-width="4" stroke-linecap="round"/>
  <text x="128" y="240" text-anchor="middle" fill="#ffffff" font-family="monospace" font-size="16">ASNUX</text>
</svg>
ICON

cp "${APP_DIR}/usr/share/icons/hicolor/256x256/apps/asnux.svg" "${APP_DIR}/asnux.svg"

# Download appimagetool if not present
if ! command -v appimagetool &>/dev/null; then
    echo "Telechargement de appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O /tmp/appimagetool
    chmod +x /tmp/appimagetool
    APPIMAGETOOL=/tmp/appimagetool
else
    APPIMAGETOOL=$(command -v appimagetool)
fi

ARCH=x86_64 $APPIMAGETOOL "${APP_DIR}" dist/ASNUX-1.0.0-x86_64.AppImage
echo "AppImage cree: dist/ASNUX-1.0.0-x86_64.AppImage"
