#!/bin/bash
set -e

echo "=== Construction de la formule Homebrew/Linuxbrew pour ASNUX ==="

DIST_DIR="dist/homebrew"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/asnux.rb" << 'HOMEBREW'
class Asnux < Formula
  desc "ASNUX Low-Latency Audio Engine for Linux - Equivalent ASIO4ALL"
  homepage "https://github.com/asnux/asnux"
  url "https://github.com/asnux/asnux/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "GPL-2.0-only"
  head "https://github.com/asnux/asnux.git", branch: "main"

  depends_on "rust" => :build
  depends_on "pkg-config" => :build
  depends_on "alsa-lib"

  def install
    # Build Rust workspace
    system "cargo", "build", "--release", "--workspace"

    # Build kernel module
    system "make", "-C", "kernel"

    # Install binaries
    bin.install "target/release/asnux-daemon"
    bin.install "target/release/asnux-gui"

    # Install kernel module
    (lib/"modules").install "kernel/asnux.ko"

    # Install systemd service
    (lib/"systemd/system").install "daemon/asnux-daemon.service"

    # Install desktop entry
    (share/"applications").install "gui/asnux-gui.desktop"
  end

  def post_install
    system "depmod", "-a" if File.exist?("/sbin/depmod")
    system "systemctl", "daemon-reload" if File.exist?("/bin/systemctl")
  end

  def caveats
    <<~EOS
      ASNUX est installe sur votre systeme.
      
      Demarrer le daemon:
        sudo systemctl start asnux-daemon
      
      Activer au demarrage:
        sudo systemctl enable asnux-daemon
      
      Lancer l'interface graphique:
        asnux-gui
    EOS
  end

  test do
    assert_match "ASNUX", shell_output("#{bin}/asnux-daemon --version 2>&1", 1)
  end
end
HOMEBREW

echo "Formule Homebrew cree: ${DIST_DIR}/asnux.rb"
echo "  Installation: brew install --build-from-source ${DIST_DIR}/asnux.rb"
echo "  Ou: brew tap asnux/tap && brew install asnux"
