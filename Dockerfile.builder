# Builder image for producing SOLIS SD-card images on a non-Linux host (e.g. macOS
# via Docker Desktop).  The actual build still needs `docker run --privileged`
# (loop devices / chroot / mounts) — see build-in-docker.sh.
#
# IMPORTANT: this is pinned to linux/amd64 on purpose.
#   * Rockchip's U-Boot build uses PREBUILT x86_64 helper tools (image mergers).
#     On an arm64 host those fail under Rosetta ("failed to open elf
#     .../ld-linux-x86-64.so.2"), so the bootloader never gets built.
#   * On Apple Silicon this image runs under emulation (slower, but correct).
FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Some Rockchip helper tools are 32-bit x86; enable i386 multiarch.
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
      sudo git curl wget ca-certificates xz-utils \
      debootstrap qemu-user-static binfmt-support eatmydata \
      parted gdisk dosfstools e2fsprogs btrfs-progs xfsprogs exfatprogs \
      bc build-essential bison flex ccache debconf-utils device-tree-compiler \
      jq lz4 lzop p7zip-full zip unzip rsync python-is-python3 \
      libssl-dev libncurses-dev u-boot-tools \
      libc6:i386 libstdc++6:i386 zlib1g:i386 \
      binutils-aarch64-linux-gnu \
      gcc-12-aarch64-linux-gnu g++-12-aarch64-linux-gnu \
 && rm -rf /var/lib/apt/lists/*

# Old Rockchip U-Boot + 4.4 BSP kernel do NOT compile with GCC 13/14.
# Make the unversioned aarch64 cross-compiler resolve to GCC 12 so that both
# U-Boot's make.sh and the kernel's CROSS_COMPILE=aarch64-linux-gnu- use it.
RUN ln -sf /usr/bin/aarch64-linux-gnu-gcc-12 /usr/bin/aarch64-linux-gnu-gcc \
 && ln -sf /usr/bin/aarch64-linux-gnu-g++-12 /usr/bin/aarch64-linux-gnu-g++ \
 && aarch64-linux-gnu-gcc --version | head -1

WORKDIR /build
