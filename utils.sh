#!/bin/bash

# Set build date
BUILD_DATE=$(date "+%m%d%Y")

# Set http/https buffer to over 500MB to minimize on possible git clone infinite hangs
git config --global http.postBuffer 524288000

# Verify the correct toolchain is available
OPT_TOOLCHAIN_DIR="/opt/toolchains/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
LOCAL_TOOLCHAIN_DIR="prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"

if [ -d "$OPT_TOOLCHAIN_DIR" ]; then
  echo "Using existing system-wide toolchain at $OPT_TOOLCHAIN_DIR"
elif [ ! -d "$LOCAL_TOOLCHAIN_DIR" ]; then
  echo "Toolchain not found. Downloading Linaro toolchain to local prebuilts directory..."
  mkdir -p "$LOCAL_TOOLCHAIN_DIR"
  git clone --depth=1 https://github.com/christianhaitian/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu.git "$LOCAL_TOOLCHAIN_DIR"
  verify_action
else
  echo "Using existing local toolchain at $LOCAL_TOOLCHAIN_DIR"
fi

# Verify package cache directory exists
if [ ! -d "Arkbuild_package_cache/${CHIPSET}" ]; then
  mkdir -p Arkbuild_package_cache/${CHIPSET}
fi

# Setup the necessary exports
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
if [ -d "$OPT_TOOLCHAIN_DIR" ]; then
    export PATH="$OPT_TOOLCHAIN_DIR"/bin/:$PATH
else
    export PATH="$LOCAL_TOOLCHAIN_DIR"/bin/:$PATH
fi
if [ "$CHIPSET" == "rk3326" ]; then
  export whichmali=libmali-bifrost-g31-rxp0-gbm.so
else
  export whichmali=libmali-bifrost-g52-g29p1.so
fi

function verify_action() {
  code=$?
  if [ $code != 0 ]; then
    echo -e "Exiting build with return code ${code}"
    exit 1
  fi
}

function get_file() {
  wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 30 --no-check-certificate "$@"
  if [ -f "wget-log" ]; then
    rm -f wget-log*
  fi
}

function call_chroot() {
  sudo chroot Arkbuild bash -c "source /root/.bashrc && $@"
}

function call_chroot32() {
  if [ ! -d Arkbuild32 ]; then
    setup_arkbuild32
  fi
  sudo chroot Arkbuild32 bash -c "source /root/.bashrc && $@"
}

function setup_ark_user() {
  if [ "$1" == "32" ]; then
    CHROOT_DIR="Arkbuild32"
  else
    CHROOT_DIR="Arkbuild"
  fi
  sudo chroot ${CHROOT_DIR}/ useradd ark -k /etc/skel -d /home/ark -m -s /bin/bash
  sudo chroot ${CHROOT_DIR}/ bash -c "echo ark:ark | chpasswd"
  sudo chroot ${CHROOT_DIR}/ chage -I -1 -m 0 -M 99999 -E -1 ark
  sudo mkdir -p ${CHROOT_DIR}/etc/sudoers.d
  echo "ark     ALL= NOPASSWD: ALL" | sudo tee ${CHROOT_DIR}/etc/sudoers.d/ark-no-sudo-password
  echo "Defaults        !secure_path" | sudo tee ${CHROOT_DIR}/etc/sudoers.d/ark-no-secure-path
  sudo chmod 0440 ${CHROOT_DIR}/etc/sudoers.d/ark-no-sudo-password
  sudo chmod 0440 ${CHROOT_DIR}/etc/sudoers.d/ark-no-secure-path
  sudo chroot ${CHROOT_DIR}/ usermod -G video,sudo,render,netdev,input,audio,adm,ark ark
  directories=(".config" ".emulationstation")
  for dir in "${directories[@]}"; do
    sudo mkdir -p "${CHROOT_DIR}/home/ark/${dir}"
  done
  echo -e "export LC_All=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/home/ark/.bashrc > /dev/null
  echo -e "export LC_CTYPE=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/home/ark/.bashrc > /dev/null
  sudo chroot ${CHROOT_DIR}/ chown -R ark:ark /home/ark/
}

function setup_arkbuild32() {
  if [ ! -d Arkbuild32 ]; then
    # Bootstrap base system
    sudo debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=armhf --foreign ${DEBIAN_CODE_NAME} Arkbuild32 http://deb.debian.org/debian/
    sudo cp /usr/bin/qemu-arm-static Arkbuild32/usr/bin/
    echo 'Acquire::http::proxy "http://127.0.0.1:3142";' | sudo tee Arkbuild32/etc/apt/apt.conf.d/99proxy
    sudo chroot Arkbuild32/ apt -y update
    sudo chroot Arkbuild32/ apt -y install eatmydata
    sudo chroot Arkbuild32/ eatmydata /debootstrap/debootstrap --second-stage

    # Bind essential host filesystems into chroot for networking
    sudo mount --bind /dev Arkbuild32/dev
    sudo mount -t devpts none Arkbuild32/dev/pts -o newinstance,ptmxmode=0666
    #sudo mount --bind /dev/pts Arkbuild32/dev/pts
    sudo mount --bind /proc Arkbuild32/proc
    sudo mount --bind /sys Arkbuild32/sys
    echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee Arkbuild32/etc/resolv.conf > /dev/null
    # Install libmali, DRM, and GBM libraries for rk3326 or rk3566
    sudo chroot Arkbuild32/ apt install -y libdrm-dev libgbm1
    setup_ark_user 32
    sudo mkdir -p Arkbuild32/home/ark
    #sudo chroot Arkbuild32/ umount /proc
    source build_deps.sh 32
    source build_sdl2.sh 32
    sudo cp -a Arkbuild32/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} Arkbuild/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension}
    sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2.so /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0"
    sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} /usr/lib/arm-linux-gnueabihf/libSDL2.so"
    sudo cp -a Arkbuild32/home/ark/linux-rga/build/librga.so* Arkbuild/usr/lib/arm-linux-gnueabihf/
    sudo cp -a Arkbuild32/home/ark/libgo2/libgo2.so* Arkbuild/usr/lib/arm-linux-gnueabihf/
    # Place libmali manually (assumes you have libmali.so or mali drivers ready)
    sudo mkdir -p Arkbuild32/usr/lib/arm-linux-gnueabihf/
    wget -t 3 -T 60 --no-check-certificate https://github.com/christianhaitian/${CHIPSET}_core_builds/raw/refs/heads/master/mali/armhf/${whichmali}
    sudo mv ${whichmali} Arkbuild32/usr/lib/arm-linux-gnueabihf/.
    cd Arkbuild32/usr/lib/arm-linux-gnueabihf
    sudo ln -sf ${whichmali} libMali.so
    for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libOpenCL.so.1 libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
    do
      sudo rm -fv ${LIB}
      sudo ln -sfv libMali.so ${LIB}
    done
    cd ../../../../
	sudo chroot Arkbuild32/ ldconfig -X
  fi
}

function remove_arkbuild() {
  for m in home/ark/Arkbuild_ccache proc dev/pts dev dev sys
  do
    if grep -qs "Arkbuild/${m} " /proc/mounts; then
      sudo umount -l Arkbuild/${m}
      verify_action
      sync
      sleep 1
    fi
  done
  sudo rm -rf Arkbuild/home/ark/Arkbuild_ccache
  (cat /proc/mounts | grep -qs "Arkbuild") && sudo umount -l Arkbuild
  (cat /proc/mounts | grep -qs "Arkbuild-final") && sudo umount -l Arkbuild-final
  return 0
}

function remove_arkbuild32() {
  for m in home/ark/Arkbuild_ccache proc dev/pts dev sys
  do
    if grep -qs "Arkbuild32/${m} " /proc/mounts; then
      sudo umount -l Arkbuild32/${m}
      verify_action
      sync
      sleep 1
    fi
  done
  (cat /proc/mounts | grep -qs "Arkbuild32") && sudo umount -l Arkbuild32
  [ -d "Arkbuild32" ] && sudo rm -rf Arkbuild32
  return 0
}

updateapt="N"

# Every chroot call here is an emulated aarch64 process, so the two things that
# matter for wall clock are how many of them there are and how many separate apt
# transactions they add up to.  The old shape of this function was one `dpkg -s`
# plus one `apt install` per package: for the 145 entries of needed_packages.txt
# and needed_dev_packages.txt that is 145 apt solver runs and 145 rounds of dpkg
# trigger processing (ldconfig, man-db, initramfs) under qemu.  One dpkg-query to
# find what is missing and one apt transaction to install all of it does the same
# work once.  The per-package loop is kept as a fallback so a single unavailable
# package still degrades to "skip that one" instead of failing the whole batch.
function apt_update_once() {
  local CHROOT_DIR="$1"
  if [[ "$updateapt" == "N" ]]; then
    if test -z "$(cat ${CHROOT_DIR}/etc/apt/sources.list | grep contrib)"
    then
      sudo sed -i '/main/s//main contrib non-free non-free-firmware/' ${CHROOT_DIR}/etc/apt/sources.list
    fi
    sudo chroot ${CHROOT_DIR}/ apt -y update
    updateapt="Y"
  fi
}

function install_package() {
  if [ "$1" == "32" ]; then
    NEEDED_ARCH=""
    CHROOT_DIR="Arkbuild32"
  elif [ "$1" == "armhf" ]; then
    NEEDED_ARCH=":armhf"
    CHROOT_DIR="Arkbuild"
  else
    NEEDED_ARCH=":arm64"
    CHROOT_DIR="Arkbuild"
  fi
  neededlibs=( ${@:2} )
  [ ${#neededlibs[@]} -eq 0 ] && return 0

  # One emulated dpkg-query for the whole batch instead of one `dpkg -s` each.
  # ${Architecture} is compared against the requested one; "all" matches anything.
  local installed_arch installed_names
  installed_arch=$(sudo chroot ${CHROOT_DIR}/ dpkg-query -W \
    -f '${Package} ${Architecture} ${db:Status-Status}\n' 2>/dev/null \
    | awk '$3 == "installed" { print $1 ":" $2 }')
  installed_names=$(echo "${installed_arch}" | cut -d: -f1)

  local wanted_arch="${NEEDED_ARCH#:}"
  local missing=()
  local libs
  for libs in "${neededlibs[@]}"
  do
     # -Fx throughout: package names carry '+' and '.' (libstdc++6, python3.11), and
     # an unanchored match would let gzip satisfy a request for zip.
     if [ -n "${wanted_arch}" ]; then
       echo "${installed_arch}" | grep -Fxq -e "${libs}:${wanted_arch}" -e "${libs}:all" && continue
     else
       # No architecture was requested (the 32-bit chroot): any architecture counts.
       echo "${installed_names}" | grep -Fxq -e "${libs}" && continue
     fi
     missing+=( "${libs}${NEEDED_ARCH}" )
  done
  [ ${#missing[@]} -eq 0 ] && return 0

  apt_update_once "${CHROOT_DIR}"

  # apt solves a transaction atomically: one name it cannot resolve fails the whole
  # batch.  That matters here because build_deps.sh feeds the same two 64-bit lists
  # to the armhf chroot, where some of them do not exist.  Ask apt once which names
  # it actually knows and drop the rest, so the batch is not set up to fail.
  local known unknown=()
  known=$(sudo chroot ${CHROOT_DIR}/ bash -c "apt-cache --no-all-versions show ${missing[*]} 2>/dev/null" \
    | awk '/^Package: /{print $2}' | sort -u)
  local candidates=()
  for libs in "${missing[@]}"
  do
     if echo "${known}" | grep -Fxq "${libs%%:*}"; then
       candidates+=( "${libs}" )
     else
       unknown+=( "${libs}" )
     fi
  done
  [ ${#unknown[@]} -gt 0 ] && echo "Not available in this chroot, skipping: ${unknown[*]}"
  [ ${#candidates[@]} -eq 0 ] && return 0

  # One transaction for everything that is missing and installable.
  sudo chroot ${CHROOT_DIR}/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt -y install ${candidates[*]}"
  if [[ $? == "0" ]]; then
    echo "${candidates[*]} were successfully installed."
    return 0
  fi

  echo " "
  echo "Batch install failed; retrying the ${#candidates[@]} packages one at a time."
  for libs in "${candidates[@]}"
  do
     sudo chroot ${CHROOT_DIR}/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt -y install ${libs}"
     if [[ $? != "0" ]]; then
       echo " "
       echo "Could not install needed library ${libs}."
     else
       echo "${libs} was successfully installed."
     fi
  done
}

function protect_package() {
  if [ "$1" == "32" ]; then
    CHROOT_DIR="Arkbuild32"
  else
    CHROOT_DIR="Arkbuild"
  fi
  protectlibs=( ${@:2} )
  [ ${#protectlibs[@]} -eq 0 ] && return 0
  # apt-mark takes a list; one emulated invocation instead of one per package.
  sudo chroot ${CHROOT_DIR}/ apt-mark manual "${protectlibs[@]}"
  if [[ $? != "0" ]]; then
    echo "apt-mark reported a problem; at least one of these is not installed: ${protectlibs[*]}"
  else
    echo "${protectlibs[*]} have been marked as manually installed."
  fi
}
