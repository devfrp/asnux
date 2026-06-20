#!/bin/bash
set -e

echo "=== Construction de l'installateur universel (runfile) ASNUX ==="

DIST_DIR="dist/runfile"
mkdir -p "${DIST_DIR}/payload"

# Binaires
cp ../target/release/asnux-daemon "${DIST_DIR}/payload/"
cp ../target/release/asnux-gui "${DIST_DIR}/payload/"
cp ../kernel/asnux.ko "${DIST_DIR}/payload/"
cp ../daemon/asnux-daemon.service "${DIST_DIR}/payload/"
cp ../gui/asnux-gui.desktop "${DIST_DIR}/payload/"

strip "${DIST_DIR}/payload/asnux-daemon" "${DIST_DIR}/payload/asnux-gui" 2>/dev/null || true

# Script d'installation embarque
cat > "${DIST_DIR}/payload/install.sh" << 'INSTALL'
#!/bin/bash
# Installation ASNUX - Extrait par le runfile
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detection de la distro
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    elif [ -f /etc/SuSE-release ]; then
        echo "suse"
    elif [ -f /etc/slackware-version ]; then
        echo "slackware"
    else
        echo "unknown"
    fi
}

install_deps() {
    local distro="$1"
    echo "Detection de la distribution: $distro"

    case "$distro" in
        debian|ubuntu|mint|pop|kali|deepin)
            apt-get update
            apt-get install -y alsa-utils pulseaudio systemd linux-headers-$(uname -r) || true
            ;;
        fedora|rhel|centos)
            dnf install -y alsa-utils pulseaudio systemd kernel-devel || true
            ;;
        arch|manjaro|endeavouros)
            pacman -Sy --noconfirm alsa-utils pulseaudio systemd linux-headers || true
            ;;
        alpine)
            apk add alsa-utils pulseaudio systemd linux-headers || true
            ;;
        suse|opensuse)
            zypper install -y alsa-utils pulseaudio systemd kernel-devel || true
            ;;
        slackware)
            echo "Veuillez installer manuellement: alsa-utils, pulseaudio, systemd"
            ;;
        *)
            echo "Distribution non reconnue. Installation des binaires seulement."
            ;;
    esac
}

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║      Installation d'ASNUX Audio Engine        ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

DISTRO=$(detect_distro)
echo "Distribution: $DISTRO"
echo ""

# Installation automatique des dependances
install_deps "$DISTRO" || true

# Installation des binaires
echo ""
echo "Installation des binaires..."
install -Dm755 "${SCRIPT_DIR}/asnux-daemon" "/usr/local/bin/asnux-daemon"
install -Dm755 "${SCRIPT_DIR}/asnux-gui" "/usr/local/bin/asnux-gui"
echo "  Binaires -> /usr/local/bin/"

# Installation du module noyau
echo "Installation du module noyau..."
KERNEL_DIR="/lib/modules/$(uname -r)/kernel/drivers/sound"
mkdir -p "$KERNEL_DIR"
install -Dm644 "${SCRIPT_DIR}/asnux.ko" "${KERNEL_DIR}/asnux.ko"
depmod -a
echo "  Module -> ${KERNEL_DIR}/asnux.ko"

# Service systemd
echo "Installation du service systemd..."
install -Dm644 "${SCRIPT_DIR}/asnux-daemon.service" "/usr/lib/systemd/system/asnux-daemon.service"
systemctl daemon-reload
echo "  Service -> /usr/lib/systemd/system/asnux-daemon.service"

# Desktop entry
echo "Installation de l'entree de menu..."
install -Dm644 "${SCRIPT_DIR}/asnux-gui.desktop" "/usr/share/applications/asnux-gui.desktop"
echo "  Desktop -> /usr/share/applications/asnux-gui.desktop"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  Installation terminee !                       ║"
echo "║                                               ║"
echo "║  Demarrer le daemon:                           ║"
echo "║    systemctl start asnux-daemon                ║"
echo "║                                               ║"
echo "║  Activer au demarrage:                         ║"
echo "║    systemctl enable asnux-daemon               ║"
echo "║                                               ║"
echo "║  Lancer l'interface:                           ║"
echo "║    asnux-gui                                   ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

systemctl enable asnux-daemon 2>/dev/null || true
systemctl start asnux-daemon 2>/dev/null || true
echo "Daemon demarre et active au demarrage !"
INSTALL

# Creer le runfile auto-extractible
cd "${DIST_DIR}"

# Compresser le payload
tar czf payload.tar.gz payload/

# Creer le script d'extraction
INSTALLER_NAME="install_asnux-1.0.1.sh"
cat > "${INSTALLER_NAME}" << 'RUNFILE_HEADER'
#!/bin/bash
# ASNUX Audio Engine v1.0.1 - Universal Installer
# Extrait et lance l'installation
set -e

echo "Extraction des fichiers..."
ARCHIVE=$(grep -a -n "__ARCHIVE_MARKER__" "$0" | tail -1 | cut -d: -f1)
if [ -z "$ARCHIVE" ]; then
    echo "Erreur: archive corrompue"
    exit 1
fi
ARCHIVE=$((ARCHIVE + 1))

CWD=$(mktemp -d)
trap "rm -rf $CWD" EXIT

tail -n +$ARCHIVE "$0" | tar xz -C "$CWD"

exec "$CWD/install.sh" "$@"

exit 0
__ARCHIVE_MARKER__
RUNFILE_HEADER

cat payload.tar.gz >> "${INSTALLER_NAME}"
chmod +x "${INSTALLER_NAME}"

echo "Runfile cree: ${DIST_DIR}/${INSTALLER_NAME} ($(du -h ${INSTALLER_NAME} | cut -f1))"
echo "  Utilisation: sudo ./${INSTALLER_NAME}"
