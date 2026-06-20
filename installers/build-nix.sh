#!/bin/bash
set -e

echo "=== Construction du package Nix pour ASNUX ==="

DIST_DIR="dist/nix"
mkdir -p "${DIST_DIR}"

cat > "${DIST_DIR}/default.nix" << 'NIX'
{ lib, stdenv, rustPlatform, fetchFromGitHub, linuxPackages, systemd, alsa-lib, pkg-config
, withPulseAudio ? true, pulseaudio ? null
, withPipeWire ? true, pipewire ? null
}:

let
  kernel = linuxPackages;
in

rustPlatform.buildRustPackage rec {
  pname = "asnux";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "asnux";
    repo = "asnux";
    rev = "v${version}";
    sha256 = "0000000000000000000000000000000000000000000000000000";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "eframe-0.28.0" = "0000000000000000000000000000000000000000000000000000";
    };
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ alsa-lib systemd ]
    ++ lib.optionals withPulseAudio [ pulseaudio ]
    ++ lib.optionals withPipeWire [ pipewire ];

  postBuild = ''
    make -C kernel
  '';

  postInstall = ''
    # Binaries
    install -Dm755 target/release/asnux-daemon -t $out/bin/
    install -Dm755 target/release/asnux-gui -t $out/bin/

    # Kernel module
    install -Dm644 kernel/asnux.ko -t $out/lib/modules/

    # Systemd service
    install -Dm644 daemon/asnux-daemon.service \
      -t $out/lib/systemd/system/

    # Desktop entry
    install -Dm644 gui/asnux-gui.desktop \
      -t $out/share/applications/
  '';

  meta = with lib; {
    description = "ASNUX Low-Latency Audio Engine for Linux";
    homepage = "https://github.com/asnux/asnux";
    license = licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    maintainers = [ maintainers.asnux ];
  };
}
NIX

cat > "${DIST_DIR}/flake.nix" << 'FLAKE'
{
  description = "ASNUX - Low-Latency Audio Engine for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
      in {
        packages = rec {
          default = asnux;
          asnux = pkgs.callPackage ./default.nix { };
        };

        nixosModules.asnux = import ./module.nix;

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.asnux}/bin/asnux-gui";
        };
      }
    );
}
FLAKE

cat > "${DIST_DIR}/module.nix" << 'MODULE'
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.asnux;
in {
  options.services.asnux = {
    enable = mkEnableOption "ASNUX audio engine";
    bufferSize = mkOption {
      type = types.int;
      default = 256;
      description = "Taille du buffer en echantillons";
    };
    sampleRate = mkOption {
      type = types.int;
      default = 48000;
      description = "Taux d'echantillonnage en Hz";
    };
    defaultEngine = mkOption {
      type = types.bool;
      default = false;
      description = "Utiliser comme moteur audio par defaut";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ asnux ];

    boot.kernelModules = [ "asnux" ];
    boot.extraModulePackages = [ pkgs.asnux ];

    systemd.services.asnux-daemon = {
      description = "ASNUX Audio Daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "sound.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.asnux}/bin/asnux-daemon";
        Restart = "on-failure";
        Nice = -10;
        CPUSchedulingPolicy = "fifo";
        CPUSchedulingPriority = 80;
        LimitRTPRIO = 99;
        LimitMEMLOCK = "infinity";
      };
    };
  };
}
MODULE

echo "Package Nix cree dans ${DIST_DIR}"
echo "  Installation: nix profile install github:asnux/asnux"
echo "  Ou: ajouter asnux dans configuration.nix"
