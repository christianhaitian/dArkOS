#!/bin/bash
# ==============================================================================
# Fetch older Debian library versions for PortMaster compatibility
# Sourced by finishing_touches.sh and finishing_touches-rk3566.sh
# Requires: utils.sh (verify_action, call_chroot), BUILD_ARMHF env var
# ==============================================================================

install_lib() {
    local url="$1"
    local lib_name="$2"
    local wildcard="$3"

    echo "Processing $lib_name..."

    # --- ARM64 ---
    local deb_arm64=$(basename "$url")
    wget -t 3 -T 60 --no-check-certificate "$url"
    #verify_action
    dpkg --fsys-tarfile "$deb_arm64" | tar -xO --wildcards "*$wildcard*" > "$lib_name"
    if [ ! -s "$lib_name" ]; then
        echo "[Error] Extraction failed for $lib_name"
    fi
    sudo mv -f "$lib_name" Arkbuild/usr/lib/aarch64-linux-gnu/
    call_chroot "chown root:root /usr/lib/aarch64-linux-gnu/$lib_name"
    rm -f "$deb_arm64"

    # --- ARMHF ---
    if [[ "${BUILD_ARMHF}" == "y" ]]; then
        local url_armhf="${url//_arm64/_armhf}"
        local deb_armhf=$(basename "$url_armhf")
        wget -t 3 -T 60 --no-check-certificate "$url_armhf"
        #verify_action
        dpkg --fsys-tarfile "$deb_armhf" | tar -xO --wildcards "*$wildcard*" > "$lib_name"
        if [ ! -s "$lib_name" ]; then
            echo "[Error] Extraction failed for $lib_name (armhf)"
        fi
        sudo mv -f "$lib_name" Arkbuild/usr/lib/arm-linux-gnueabihf/
        call_chroot "chown root:root /usr/lib/arm-linux-gnueabihf/$lib_name"
        rm -f "$deb_armhf"
    fi
}

# libjpeg8 (Debian snapshot, 2014) - PortMaster compatibility
install_lib \
    "https://snapshot.debian.org/archive/debian/20141009T042436Z/pool/main/libj/libjpeg8/libjpeg8_8d1-2_arm64.deb" \
    "libjpeg.so.8" "libjpeg.so.8"

# The Debian 11 (Bullseye) security packages below fetch from
# snapshot.debian.org by content hash. Their security.debian.org pool URLs
# 404 now that Bullseye has moved to the archive - a silent miss, since
# install_lib is non-fatal. snapshot is official Debian, permanent, and
# content-addressed. Each block's comment names the package and version;
# resolve a hash with https://snapshot.debian.org/mr/binary/<pkg>/<version>/binfiles
# libavcodec58 (FFmpeg 4.3.9, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/1cd81b02fb5204950ed672c40f909a39c97a3eec" \
    "libavcodec.so.58" "libavcodec.so.58"

# libavutil56 (FFmpeg 4.3.9, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/77837095301a492e6ffd0bd022bc9eed4ba68224" \
    "libavutil.so.56" "libavutil.so.56"

# libswresample3 (FFmpeg 4.3.9, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/7dee130b0cfb0581db1a1887c172f0c86d5c5edf" \
    "libswresample.so.3" "libswresample.so.3"

# libavformat58 (FFmpeg 4.3.9, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/5e3824992166317cdd045c556533316b64106b3b" \
    "libavformat.so.58" "libavformat.so.58"

# libswscale5 (FFmpeg 4.3.9, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/b2aa4db4df008adbbdaffaee37f9bac96bf1a894" \
    "libswscale.so.5" "libswscale.so.5"

# libvpx6 (1.9.0, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/a3163a6e5ea7a3f2c591a49f57e5f349fa188c91" \
    "libvpx.so.6" "libvpx.so.6"

# libwebp6 (0.6.1, Debian 11 security)
install_lib \
    "http://ftp.debian.org/debian/pool/main/libw/libwebp/libwebp6_0.6.1-2.1+deb11u2_arm64.deb" \
    "libwebp.so.6" "libwebp.so.6"

# libaom0 (1.0.0, Debian 11 security)
install_lib \
    "https://snapshot.debian.org/file/190db33dc1f13b36a21145169c313f1698e5965f" \
    "libaom.so.0" "libaom.so.0"

# libdav1d4 (0.7.1, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/d/dav1d/libdav1d4_0.7.1-3+deb11u1_arm64.deb" \
    "libdav1d.so.4" "libdav1d.so.4"

# libcodec2 (0.9.2, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/c/codec2/libcodec2-0.9_0.9.2-4_arm64.deb" \
    "libcodec2.so.0.9" "libcodec2.so.0.9"

# libwavpack1 (5.4.0, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/w/wavpack/libwavpack1_5.4.0-1_arm64.deb" \
    "libwavpack.so.1" "libwavpack.so.1"

# libx264 (0.160, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/x/x264/libx264-160_0.160.3011+gitcde9a93-2.1_arm64.deb" \
    "libx264.so.160" "libx264.so.160"

# libx265 (3.4, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/x/x265/libx265-192_3.4-2_arm64.deb" \
    "libx265.so.192" "libx265.so.192"

# libflac8 (1.3.3, Debian 11)
install_lib \
    "http://ftp.debian.org/debian/pool/main/f/flac/libflac8_1.3.3-2+deb11u2_arm64.deb" \
    "libFLAC.so.8" "libFLAC.so.8"

# libvpx5 (1.7.0, Debian 10 Buster) - PortMaster compatibility
install_lib \
    "http://archive.debian.org/debian/pool/main/libv/libvpx/libvpx5_1.7.0-3+deb10u1_arm64.deb" \
    "libvpx.so.5" "libvpx.so.5"

# libx264-155 (0.155, Debian 10 Buster) - PortMaster compatibility
install_lib \
    "http://archive.debian.org/debian/pool/main/x/x264/libx264-155_0.155.2917+git0a84d98-2_arm64.deb" \
    "libx264.so.155" "libx264.so.155"

# libx265-165 (2.9, Debian 10 Buster) - PortMaster compatibility
install_lib \
    "http://archive.debian.org/debian/pool/main/x/x265/libx265-165_2.9-4_arm64.deb" \
    "libx265.so.165" "libx265.so.165"

# libcodec2-0.8.1 (0.8.1, Debian 10 Buster) - PortMaster compatibility
install_lib \
    "http://archive.debian.org/debian/pool/main/c/codec2/libcodec2-0.8.1_0.8.1-2_arm64.deb" \
    "libcodec2.so.0.8.1" "libcodec2.so.0.8.1"

# libsrt-gnutls.so.1.4 (1.4.2, Debian 11 Bullseye) - PortMaster compatibility
install_lib \
    "http://ftp.us.debian.org/debian/pool/main/s/srt/libsrt1.4-gnutls_1.4.2-1.3_arm64.deb" \
	"libsrt-gnutls.so.1.4.2" "libsrt-gnutls.so.1.4.2"

# libssh-gcrypt4 (0.8.7, Debian 10 Buster) - PortMaster compatibility
install_lib \
    "http://archive.debian.org/debian/pool/main/libs/libssh/libssh-gcrypt-4_0.8.7-1+deb10u1_arm64.deb" \
    "libssh-gcrypt.so.4" "libssh-gcrypt.so.4"

