#!/usr/bin/env bash
# Build a SOLIS SD-card image inside a privileged Docker container.
# Intended for macOS / non-Linux hosts where the build cannot run directly.
#
# Usage:   ./build-in-docker.sh [device]
#   device = g350 (default) | rg351mp | rgb10 | a10mini
#
# Output:  dArkOS_<DEVICE>_trixie_<date>.img (+ split .7z) land in this folder.
set -euo pipefail

DEVICE="${1:-g350}"
case "$DEVICE" in
  g350|rg351mp|rgb10|a10mini) ;;
  *) echo "Unknown device '$DEVICE'. Use: g350 | rg351mp | rgb10 | a10mini"; exit 1 ;;
esac

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="solis-builder"
# Pinned to amd64: Rockchip's U-Boot uses prebuilt x86_64 helper tools, which do
# not run on an arm64 host. On Apple Silicon this runs under emulation (slower).
PLATFORM="linux/amd64"

# Register qemu binfmt handlers in the Docker VM (needed for the aarch64
# debootstrap second stage). Harmless if already present.
echo ">> Registering qemu binfmt handlers..."
docker run --privileged --rm tonistiigi/binfmt --install all >/dev/null 2>&1 || true

echo ">> Building the builder image ($PLATFORM)..."
docker build --platform "$PLATFORM" -t "$IMAGE_TAG" -f "$REPO_DIR/Dockerfile.builder" "$REPO_DIR"

echo ">> Building SOLIS image for '$DEVICE' (this takes a while)..."
# --privileged + /dev for loop devices, parted, chroot, bind mounts.
# ENABLE_CACHE=n because there is no systemd/apt-cacher-ng inside the container.
docker run --rm -it --platform "$PLATFORM" --privileged \
  -v /dev:/dev \
  -v "$REPO_DIR":/build \
  -w /build \
  -e ENABLE_CACHE=n \
  "$IMAGE_TAG" \
  make "$DEVICE"

echo ">> Done. Image(s) in: $REPO_DIR"
ls -lh "$REPO_DIR"/*.img 2>/dev/null || true
