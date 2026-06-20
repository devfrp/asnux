#!/bin/bash
# ASNUX — Installateur universel (curl)
# Usage : curl -sSL https://devfrp.github.io/asnux/install.sh | sudo bash
set -e

VERSION="${ASNUX_VERSION:-1.0.1}"
REPO="devfrp/asnux"
BASE_URL="https://github.com/${REPO}/releases/download/v${VERSION}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[ASNUX]${NC} $*"; }
ok()    { echo -e "${GREEN}[ASNUX]${NC} $*"; }
err()   { echo -e "${RED}[ASNUX]${NC} $*"; }

if [ "$(id -u)" -ne 0 ]; then
    err "Ce script doit etre execute en root (sudo)."
    exit 1
fi

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    elif [ -f /etc/void-release ]; then
        echo "void"
    elif [ -f /etc/slackware-version ]; then
        echo "slackware"
    elif [ -f /etc/solus-release ]; then
        echo "solus"
    elif [ -f /etc/gentoo-release ]; then
        echo "gentoo"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
info "Distribution detectee : ${DISTRO}"

download() {
    local url="$1"
    local dest="$2"
    info "Telechargement de $(basename "$dest")..."
    if command -v curl &>/dev/null; then
        curl -fsSL --progress-bar -o "$dest" "$url" || { err "Echec du telechargement : $url"; exit 1; }
    elif command -v wget &>/dev/null; then
        wget -q -O "$dest" "$url" || { err "Echec du telechargement : $url"; exit 1; }
    else
        err "Ni curl ni wget n'est installe. Installez l'un des deux."
        exit 1
    fi
    ok "Telecharge : $(basename "$dest")"
}

install_package() {
    local pkg_type="$1"
    local pkg_file="$2"
    info "Installation du package..."
    case "$pkg_type" in
        deb)
            dpkg -i "$pkg_file"
            ;;
        rpm)
            if command -v dnf &>/dev/null; then
                dnf install -y "$pkg_file" 2>/dev/null || rpm -ivh "$pkg_file"
            elif command -v zypper &>/dev/null; then
                zypper install -y "$pkg_file" 2>/dev/null || rpm -ivh "$pkg_file"
            else
                rpm -ivh "$pkg_file"
            fi
            ;;
        arch)
            pacman -U --noconfirm "$pkg_file"
            ;;
        apk)
            apk add --allow-untrusted "$pkg_file"
            ;;
        xbps)
            xbps-install -y "$pkg_file"
            ;;
        txz)
            installpkg "$pkg_file"
            ;;
        eopkg)
            eopkg install "$pkg_file"
            ;;
        tar)
            local dir=$(mktemp -d)
            tar xf "$pkg_file" -C "$dir"
            if ! "$dir/asnux-${VERSION}-linux-x86_64/install.sh"; then
                err "Echec de l'installation via tarball."
                rm -rf "$dir"
                exit 1
            fi
            rm -rf "$dir"
            return
            ;;
        *)
            err "Type de package inconnu : $pkg_type"
            exit 1
            ;;
    esac

    depmod 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable asnux-daemon 2>/dev/null || true
    systemctl start asnux-daemon 2>/dev/null || true
    ok "Daemon installe, active et demarre !"
}

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"

case "$DISTRO" in
    debian|ubuntu|linuxmint|pop|kali|deepin|parrot|elementary|zorin|mx|antix|devuan)
        URL="${BASE_URL}/asnux-${VERSION}-amd64.deb"
        download "$URL" "asnux.deb"
        install_package "deb" "asnux.deb"
        ;;
    fedora|rhel|centos|rocky|almalinux|alma|ol|oracle|amzn)
        URL="${BASE_URL}/asnux-${VERSION}-1.x86_64.rpm"
        download "$URL" "asnux.rpm"
        install_package "rpm" "asnux.rpm"
        ;;
    opensuse|suse|opensuse-tumbleweed|opensuse-leap|sles)
        URL="${BASE_URL}/asnux-${VERSION}-0.x86_64.rpm"
        download "$URL" "asnux-suse.rpm"
        install_package "rpm" "asnux-suse.rpm"
        ;;
    arch|manjaro|endeavouros|artix|arcolinux|garuda|cachyos)
        URL="${BASE_URL}/asnux-${VERSION}-1-x86_64.pkg.tar.zst"
        download "$URL" "asnux.pkg.tar.zst"
        install_package "arch" "asnux.pkg.tar.zst"
        ;;
    alpine)
        err "Alpine : veuillez utiliser abuild avec l'APKBUILD du depot."
        info "Alternative : tarball portable."
        URL="${BASE_URL}/asnux-${VERSION}-linux-x86_64.tar.gz"
        download "$URL" "asnux.tar.gz"
        install_package "tar" "asnux.tar.gz"
        ;;
    void)
        err "Void : veuillez utiliser xbps-src avec le template du depot."
        info "Alternative: tarball portable."
        URL="${BASE_URL}/asnux-${VERSION}-linux-x86_64.tar.gz"
        download "$URL" "asnux.tar.gz"
        install_package "tar" "asnux.tar.gz"
        ;;
    slackware)
        URL="${BASE_URL}/asnux-${VERSION}-x86_64.txz"
        download "$URL" "asnux.txz"
        install_package "txz" "asnux.txz"
        ;;
    solus)
        err "Solus : veuillez utiliser eopkg avec le package.yml du depot."
        info "Alternative: tarball portable."
        URL="${BASE_URL}/asnux-${VERSION}-linux-x86_64.tar.gz"
        download "$URL" "asnux.tar.gz"
        install_package "tar" "asnux.tar.gz"
        ;;
    gentoo|funtoo)
        err "Gentoo : veuillez utiliser l'ebuild du depot (emerge asnux)."
        info "Alternative: tarball portable."
        URL="${BASE_URL}/asnux-${VERSION}-linux-x86_64.tar.gz"
        download "$URL" "asnux.tar.gz"
        install_package "tar" "asnux.tar.gz"
        ;;
    nixos)
        err "NixOS : utilisez le flake nix officiel."
        info "  nix profile install github:devfrp/asnux"
        info "  Ou ajoutez asnux dans votre configuration.nix"
        exit 0
        ;;
    *)
        info "Distribution non reconnue. Utilisation du tarball portable universel."
        URL="${BASE_URL}/asnux-${VERSION}-linux-x86_64.tar.gz"
        download "$URL" "asnux.tar.gz"
        install_package "tar" "asnux.tar.gz"
        ;;
esac

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      ASNUX installe avec succes !             ║${NC}"
echo -e "${GREEN}║                                               ║${NC}"
echo -e "${GREEN}║  Daemon : deja actif (systemctl status asnux)  ║${NC}"
echo -e "${GREEN}║  GUI    : lance asnux-gui                     ║${NC}"
echo -e "${GREEN}║  Doc    : https://devfrp.github.io/asnux       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
