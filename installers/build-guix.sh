#!/bin/bash
set -e

echo "=== Construction du package GNU Guix pour ASNUX ==="

DIST_DIR="dist/guix"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/asnux.scm" << 'GUIX_PKG'
(define-module (asnux)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (guix build-system linux-module)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages crates-io)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages systemd)
  #:use-module (gnu packages freedesktop))

(define-public asnux
  (package
    (name "asnux")
    (version "1.0.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/asnux/asnux")
             (commit (string-append "v" version))))
       (file-name (git-file-name name version))
       (sha256
        (base32 "0000000000000000000000000000000000000000000000"))))
    (build-system cargo-build-system)
    (arguments
     (list
      #:cargo-inputs
      `(("rust-eframe" ,rust-eframe-0.28)
        ("rust-egui" ,rust-egui-0.28)
        ("rust-serde" ,rust-serde-1)
        ("rust-serde-json" ,rust-serde-json-1)
        ("rust-anyhow" ,rust-anyhow-1)
        ("rust-log" ,rust-log-0.4)
        ("rust-env-logger" ,rust-env-logger-0.11)
        ("rust-nix" ,rust-nix-0.29))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'build 'build-kernel-module
            (lambda _
              (invoke "make" "-C" "kernel")))
          (add-after 'install 'install-kernel-module
            (lambda _
              (install-file "kernel/asnux.ko"
                            (string-append #$output "/lib/modules"))))
          (add-after 'install 'install-service
            (lambda _
              (install-file "daemon/asnux-daemon.service"
                            (string-append #$output "/lib/systemd/system"))
              (install-file "gui/asnux-gui.desktop"
                            (string-append #$output "/share/applications")))))))
    (inputs
     (list alsa-lib systemd))
    (native-inputs
     (list linux-libre-headers pkg-config))
    (home-page "https://github.com/asnux/asnux")
    (synopsis "Low-Latency Audio Engine for Linux")
    (description
     "ASNUX fournit un moteur audio basse latence pour Linux,
equivalent a ASIO4ALL pour Windows. Inclut un driver noyau
ALSA virtuel, un daemon systeme, et une interface graphique.")
    (license license:gpl2)))

asnux
GUIX_PKG

echo "Package Guix cree dans ${DIST_DIR}"
echo "  Installation: guix package -f ${DIST_DIR}/asnux.scm"
