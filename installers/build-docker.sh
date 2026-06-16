#!/bin/bash
set -e

echo "=== Construction de l'image Docker ASNUX ==="

DIST_DIR="dist/docker"
mkdir -p "${DIST_DIR}"

# Dockerfile pour builder ASNUX (multi-stage)
cat > "${DIST_DIR}/Dockerfile" << 'DOCKERFILE'
# ===== Stage 1: Builder =====
FROM rust:latest AS builder

RUN apt-get update && apt-get install -y \
    linux-headers-amd64 \
    build-essential \
    make \
    libasound2-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN cargo build --release --workspace
RUN make -C kernel

# ===== Stage 2: Module noyau =====
FROM debian:bookworm-slim AS kernel-module
RUN apt-get update && apt-get install -y linux-headers-amd64 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /build/kernel/asnux.ko /lib/modules/$(uname -r)/kernel/drivers/sound/
RUN depmod -a

# ===== Stage 3: Runtime =====
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    alsa-utils \
    pulseaudio \
    systemd \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/target/release/asnux-daemon /usr/local/bin/
COPY --from=builder /build/target/release/asnux-gui /usr/local/bin/
COPY --from=builder /build/daemon/asnux-daemon.service /usr/lib/systemd/system/
COPY --from=builder /build/gui/asnux-gui.desktop /usr/share/applications/
COPY --from=kernel-module /lib/modules/ /lib/modules/

EXPOSE 8080

CMD ["/usr/local/bin/asnux-daemon"]
DOCKERFILE

# Docker Compose
cat > "${DIST_DIR}/docker-compose.yml" << 'COMPOSE'
services:
  asnux:
    build:
      context: ..
      dockerfile: dist/docker/Dockerfile
    container_name: asnux-audio
    network_mode: host
    devices:
      - "/dev/snd:/dev/snd"
      - "/dev/dri:/dev/dri"
    volumes:
      - "/tmp/.X11-unix:/tmp/.X11-unix:rw"
      - "/run/user/1000/pulse:/run/user/1000/pulse"
    environment:
      - DISPLAY=${DISPLAY}
      - PULSE_SERVER=unix:/run/user/1000/pulse/native
    privileged: true
    restart: unless-stopped
COMPOSE

# Docker Hub README
cat > "${DIST_DIR}/DOCKER_HUB.md" << 'DOCKERHUB'
# ASNUX sur Docker

## Tags disponibles
- `latest` - Derniere version stable
- `1.0.0` - Version specifique

## Utilisation

```bash
# Builder et lancer
docker compose up -d

# Ou manuellement
docker run -d \
  --name asnux \
  --network host \
  --device /dev/snd \
  --privileged \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  asnux/asnux:latest
```

## Pull depuis Docker Hub
```bash
docker pull asnux/asnux:latest
```
DOCKERHUB

echo "Package Docker cree dans ${DIST_DIR}"
echo "  Build: docker compose -f ${DIST_DIR}/docker-compose.yml build"
echo "  Lancement: docker compose -f ${DIST_DIR}/docker-compose.yml up"
