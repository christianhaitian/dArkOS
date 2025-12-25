#!/bin/bash

# Build and install RTL8188FU WiFi driver
# This driver supports Realtek RTL8188FTV USB WiFi adapters (VID:0bda PID:f179)

DRIVER_SRC=rtl8188fu

echo "Building RTL8188FU WiFi driver..."

# Clone the RTL8188FU driver repository if not already present
if [ ! -d "$DRIVER_SRC" ]; then
  git clone --depth=1 https://github.com/kenvL/rtl8188fu.git $DRIVER_SRC
fi

cd $DRIVER_SRC

# Get kernel version from the built kernel modules
KERNEL_VERSION=$(basename $(find ../Arkbuild/lib/modules -maxdepth 1 -mindepth 1 -type d))

if [ -z "$KERNEL_VERSION" ]; then
  echo "Error: Kernel version not found. Please build the kernel first."
  exit 1
fi

echo "Building driver for kernel version: $KERNEL_VERSION"

# Build the driver
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KSRC=../main
verify_action

# Install the driver module
sudo mkdir -p ../Arkbuild/lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtl8188fu
sudo cp rtl8188fu.ko ../Arkbuild/lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtl8188fu/

# Update module dependencies
call_chroot "depmod ${KERNEL_VERSION}"

# Create modprobe configuration to load the driver with optimal settings
echo "options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0" | sudo tee ../Arkbuild/etc/modprobe.d/rtl8188fu.conf

echo "RTL8188FU driver installed successfully!"

cd ..
