#!/bin/bash
# distcc_cross.sh - move the compile step of the emulated aarch64 chroot builds
#                   onto the host's native cross compiler.
#
# Why this exists
# ---------------
# Everything in dArkOS except the kernel and u-boot is compiled inside
# `chroot Arkbuild` (aarch64) through qemu-aarch64-static.  Measured on an
# x86-64 host, running a real compiler under qemu-user costs 7-12x wall clock
# versus running it natively (gcc cc1 on the same input: 7.4x same-arch TCG;
# tcc aarch64-on-x86: ~12x).  That multiplier applies to nearly the whole build.
#
# distcc splits the work: the chroot still drives configure, make, preprocessing
# and linking under emulation, but every actual compile is shipped to a distccd
# on the host that answers with a *native* aarch64 cross compiler.  The expensive
# part stops being emulated.
#
# What it does NOT move: linking, ar/ranlib, configure shell scripts, and
# preprocessing (plain distcc mode preprocesses on the client).  Expect a large
# but not total win.
#
# Usage
#   make <device>              # USE_DISTCC=y by default on x86-64 (prepare.sh
#                              # starts distccd, build_deps.sh points the chroot)
#   make USE_DISTCC=n <device> # keep compiles inside qemu-user
#   source ./distcc_cross.sh   # manual / extra chroots
#   distcc_host_start          # once, on the host, before the chroot builds
#   distcc_chroot_setup        # after gcc is installed in the chroot
#   ...run the build...
#   distcc_host_stop
#
# Set DISTCC_GCC_VERSION to the gcc major the chroot ends up using.  build_deps.sh
# pins the chroot to gcc-12 when Debian's default is newer, so 12 is the default
# here; keep the two in sync or distcc will hand back objects from a different
# compiler than the one the build thinks it is using.

DISTCC_GCC_VERSION="${DISTCC_GCC_VERSION:-12}"
DISTCC_CROSS_DIR="${DISTCC_CROSS_DIR:-/usr/local/lib/distcc-cross}"
DISTCC_PORT="${DISTCC_PORT:-3632}"
DISTCC_JOBS="${DISTCC_JOBS:-$(( $(nproc) * 2 ))}"

function distcc_host_start() {
  local xgcc="aarch64-linux-gnu-gcc-${DISTCC_GCC_VERSION}"
  local xgpp="aarch64-linux-gnu-g++-${DISTCC_GCC_VERSION}"

  if ! command -v "${xgcc}" >/dev/null 2>&1; then
    sudo apt-get -y update
    sudo apt-get -y install distcc \
      "gcc-${DISTCC_GCC_VERSION}-aarch64-linux-gnu" \
      "g++-${DISTCC_GCC_VERSION}-aarch64-linux-gnu" || return 1
  fi
  command -v distccd >/dev/null 2>&1 || { sudo apt-get -y update; sudo apt-get -y install distcc || return 1; }

  # distccd resolves the compiler by the name the client asked for.  The chroot
  # asks for plain gcc/cc/g++/c++ (and for the prefixed names when a build system
  # is cross-aware), so every one of those has to resolve to the cross compiler
  # here - and only here, which is why this is a private directory and not
  # /usr/local/bin.
  sudo mkdir -p "${DISTCC_CROSS_DIR}"
  # distccd is asked for whatever name the client's compiler resolved to, so all
  # of them have to exist here: the chroot's `cc` is an alternatives link to gcc,
  # which build_deps.sh points at gcc-${DISTCC_GCC_VERSION}, and cross-aware build
  # systems ask for the triplet-prefixed name.  These must shadow the host's own
  # x86 gcc-${DISTCC_GCC_VERSION}, which is why distccd is started with this
  # directory first on PATH.
  local xgcc_path xgpp_path
  xgcc_path="$(command -v ${xgcc})" || return 1
  xgpp_path="$(command -v ${xgpp})" || return 1
  [ -x "${xgcc_path}" ] && [ -x "${xgpp_path}" ] || { echo "cross compilers not found"; return 1; }

  local n
  for n in gcc cc "gcc-${DISTCC_GCC_VERSION}" aarch64-linux-gnu-gcc "${xgcc}"; do
    sudo ln -sf "${xgcc_path}" "${DISTCC_CROSS_DIR}/${n}"
  done
  for n in g++ c++ "g++-${DISTCC_GCC_VERSION}" "c++-${DISTCC_GCC_VERSION}" aarch64-linux-gnu-g++ "${xgpp}"; do
    sudo ln -sf "${xgpp_path}" "${DISTCC_CROSS_DIR}/${n}"
  done

  # distccd 3.4 refuses any compiler basename that does not also exist in
  # /usr/lib/distcc ("not in /usr/lib/distcc whitelist"), and that directory is
  # generated from the compilers installed natively on this host - so the names
  # the aarch64 chroot sends (gcc-${DISTCC_GCC_VERSION}, g++-${DISTCC_GCC_VERSION})
  # are missing from it.  Add them.  These are whitelist entries only; what
  # actually gets executed is resolved from distccd's PATH, which starts with
  # ${DISTCC_CROSS_DIR}.
  for n in "${DISTCC_CROSS_DIR}"/*; do
    [ -e "${n}" ] || continue          # unexpanded glob: nothing was linked
    n="$(basename "${n}")"
    [ -e "/usr/lib/distcc/${n}" ] || sudo ln -sf ../../bin/distcc "/usr/lib/distcc/${n}"
  done

  distcc_host_stop
  sudo env PATH="${DISTCC_CROSS_DIR}:${PATH}" distccd \
    --daemon \
    --port "${DISTCC_PORT}" \
    --listen 127.0.0.1 \
    --allow 127.0.0.1 \
    --jobs "${DISTCC_JOBS}" \
    --log-file /tmp/distccd.log \
    --log-level notice \
    --nice 5 \
    -N 5 || return 1
  sleep 1
  pgrep -x distccd >/dev/null && echo "distccd up on 127.0.0.1:${DISTCC_PORT}, serving ${xgcc}"
}

function distcc_host_stop() {
  sudo pkill -x distccd 2>/dev/null
  return 0
}

function distcc_chroot_setup() {
  local CHROOT_DIR="${1:-Arkbuild}"
  # The chroot shares the host's network namespace, so 127.0.0.1 is the host.
  sudo chroot "${CHROOT_DIR}/" bash -c \
    "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y install distcc" || return 1
  sudo mkdir -p "${CHROOT_DIR}/etc/profile.d"
  cat <<EOF | sudo tee "${CHROOT_DIR}/etc/profile.d/distcc-cross.sh" > /dev/null
# --- distcc_cross.sh ---
export DISTCC_HOSTS="127.0.0.1:${DISTCC_PORT}/${DISTCC_JOBS}"
export DISTCC_FALLBACK=1
export DISTCC_IO_TIMEOUT=600
# ccache first, distcc behind it: a cache hit costs nothing, a miss is compiled
# natively on the host instead of under qemu.
export CCACHE_PREFIX=distcc
export PATH=/usr/lib/ccache:\$PATH
# --- end distcc_cross.sh ---
EOF
  if ! sudo grep -q "distcc-cross.sh" "${CHROOT_DIR}/root/.bashrc" 2>/dev/null; then
    echo '[ -f /etc/profile.d/distcc-cross.sh ] && . /etc/profile.d/distcc-cross.sh' | \
      sudo tee -a "${CHROOT_DIR}/root/.bashrc" > /dev/null
  fi
  echo "chroot ${CHROOT_DIR} pointed at distccd; -j for the component builds can now"
  echo "exceed nproc (try 2-3x) because the compiles run off-box."
}
