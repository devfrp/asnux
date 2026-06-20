#!/bin/bash
set -e

echo "=== Construction du package Slackware (txz) pour ASNUX ==="

DIST_DIR="dist/slackware"
PKG_NAME="asnux-1.0.1-x86_64"
mkdir -p "${DIST_DIR}/${PKG_NAME}/install"
mkdir -p "${DIST_DIR}/${PKG_NAME}/usr/local/bin"
mkdir -p "${DIST_DIR}/${PKG_NAME}/lib/modules"
mkdir -p "${DIST_DIR}/${PKG_NAME}/usr/share/applications"
mkdir -p "${DIST_DIR}/${PKG_NAME}/etc/rc.d"

cp ../target/release/asnux-daemon "${DIST_DIR}/${PKG_NAME}/usr/local/bin/"
cp ../target/release/asnux-gui "${DIST_DIR}/${PKG_NAME}/usr/local/bin/"
cp ../kernel/asnux.ko "${DIST_DIR}/${PKG_NAME}/lib/modules/"
cp ../gui/asnux-gui.desktop "${DIST_DIR}/${PKG_NAME}/usr/share/applications/"

# Slackware rc script
cat > "${DIST_DIR}/${PKG_NAME}/etc/rc.d/rc.asnux" << 'RCASNUX'
#!/bin/bash
# /etc/rc.d/rc.asnux
# Demarrage/Arret du daemon ASNUX

ASNUX_DAEMON=/usr/local/bin/asnux-daemon

case "$1" in
    start)
        echo "Demarrage d'ASNUX..."
        if [ -x "${ASNUX_DAEMON}" ]; then
            /sbin/modprobe asnux 2>/dev/null || true
            ${ASNUX_DAEMON} &
            echo "ASNUX demarre"
        fi
        ;;
    stop)
        echo "Arret d'ASNUX..."
        killall asnux-daemon 2>/dev/null || true
        /sbin/modprobe -r asnux 2>/dev/null || true
        echo "ASNUX arrete"
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if pidof asnux-daemon >/dev/null 2>&1; then
            echo "ASNUX est en marche"
        else
            echo "ASNUX n'est pas en marche"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
RCASNUX
chmod +x "${DIST_DIR}/${PKG_NAME}/etc/rc.d/rc.asnux"

# doinst.sh
cat > "${DIST_DIR}/${PKG_NAME}/install/doinst.sh" << 'DOINST'
#!/bin/bash
config() {
    NEW="$1"
    OLD="$(dirname $NEW)/$(basename $NEW .new)"
    if [ ! -r "$OLD" ]; then
        mv "$NEW" "$OLD"
    elif [ "$(cat $OLD | md5sum)" = "$(cat $NEW | md5sum)" ]; then
        rm "$NEW"
    fi
}

config etc/rc.d/rc.asnux.new

if [ -x /etc/rc.d/rc.asnux ]; then
    /etc/rc.d/rc.asnux start
fi

depmod -a 2>/dev/null || true
DOINST

# slack-desc
cat > "${DIST_DIR}/${PKG_NAME}/install/slack-desc" << 'SLACKDESC'
# HOW TO EDIT THIS FILE:
# The "handy ruler" below makes it easier to edit a package description.
# Line up the first '|' above the ':' following the base package name, and
# the '|' on the right side marks the last column you can put a character in.
# You must make exactly 11 lines for the "+" sides to be aligned correctly.

asnux: asnux (Low-Latency Audio Engine for Linux)
asnux:
asnux: ASNUX fournit un moteur audio basse latence pour Linux,
asnux: equivalent a ASIO4ALL pour Windows. Inclut un driver noyau
asnux: ALSA virtuel, un daemon systeme, et une interface graphique.
asnux:
asnux: Fonctionnalites:
asnux: - Driver noyau ALSA basse latence
asnux: - GUI de configuration (buffer, sample rate)
asnux: - Moteur audio systeme par defaut
asnux: - Priorite temps reel
asnux:
asnux: Site: https://github.com/asnux/asnux
SLACKDESC

# Creer le package txz (format Slackware = tar.gz avec structure specifique)
cd "${DIST_DIR}"
tar -cJf "${PKG_NAME}.txz" "${PKG_NAME}"
echo "Package Slackware cree: ${DIST_DIR}/${PKG_NAME}.txz"
echo "  Installation: sudo installpkg ${PKG_NAME}.txz"
