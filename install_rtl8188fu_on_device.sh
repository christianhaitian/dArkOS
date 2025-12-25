#!/bin/bash

# RTL8188FU WiFi Driver Installation Script for dArkOS
# Run this script directly on your R36S device
# This will compile and install the driver on the device

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "=== RTL8188FU WiFi Driver Installer for dArkOS ==="
echo ""

# Get current kernel version
KERNEL_VERSION=$(uname -r)
echo "Kernel version: ${KERNEL_VERSION}"

# Check if kernel headers are installed
if [ ! -d "/lib/modules/${KERNEL_VERSION}/build" ] && [ ! -d "/usr/src/linux-headers-${KERNEL_VERSION}" ]; then
  echo "Warning: Kernel headers not found."
  echo "This script needs kernel headers to compile the driver."
  echo ""
  echo "You have two options:"
  echo "1. Use the pre-compiled driver package (recommended)"
  echo "2. Install kernel headers (may not be available for dArkOS)"
  echo ""
  exit 1
fi

# Install build dependencies
echo "Checking build dependencies..."
apt-get update
apt-get install -y build-essential git bc kmod

# Clone RTL8188FU driver
DRIVER_SRC="/tmp/rtl8188fu"
if [ -d "$DRIVER_SRC" ]; then
  rm -rf $DRIVER_SRC
fi

echo "Downloading RTL8188FU driver..."
git clone --depth=1 https://github.com/kelebek333/rtl8188fu.git $DRIVER_SRC
cd $DRIVER_SRC

# Build the driver
echo "Compiling driver..."
make -j$(nproc)

if [ ! -f "rtl8188fu.ko" ]; then
  echo "Error: Driver compilation failed!"
  exit 1
fi

# Install the driver module
echo "Installing kernel module..."
mkdir -p /lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtl8188fu
cp rtl8188fu.ko /lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtl8188fu/
chmod 644 /lib/modules/${KERNEL_VERSION}/kernel/drivers/net/wireless/realtek/rtl8188fu/rtl8188fu.ko

# Update module dependencies
echo "Updating module dependencies..."
depmod -a

# Create modprobe configuration
echo "Configuring driver..."
echo "options rtl8188fu rtw_power_mgnt=0 rtw_enusbss=0" > /etc/modprobe.d/rtl8188fu.conf

# Add udev rule for RTL8188FU
echo "Adding USB device rules..."
if ! grep -q "0bda.*f179" /etc/udev/rules.d/40-usb_modeswitch.rules 2>/dev/null; then
  # Backup existing file
  if [ -f /etc/udev/rules.d/40-usb_modeswitch.rules ]; then
    cp /etc/udev/rules.d/40-usb_modeswitch.rules /etc/udev/rules.d/40-usb_modeswitch.rules.backup
  fi

  # Add RTL8188FU rule before the end label
  sed -i '/LABEL="end_modeswitch"/i \
# Realtek RTL8188FTV/RTL8188FU 802.11n USB WiFi Adapter\n\
#   Direct WiFi mode, no mode switching needed\n\
ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="f179"\n' /etc/udev/rules.d/40-usb_modeswitch.rules

  echo "USB rules updated."
else
  echo "USB rules already contain RTL8188FU entry."
fi

# Reload udev rules
udevadm control --reload-rules

# Clean up
cd /
rm -rf $DRIVER_SRC

# Try to load the module
echo "Loading driver module..."
modprobe rtl8188fu 2>/dev/null || echo "Note: Module will load when USB adapter is connected"

echo ""
echo "=== Installation Complete! ==="
echo ""
echo "Next steps:"
echo "1. Connect your RTL8188FU USB WiFi adapter"
echo "2. The driver should load automatically"
echo "3. Use the WiFi menu in dArkOS to connect"
echo ""
echo "To verify: lsmod | grep rtl8188fu"
echo "To see logs: dmesg | grep rtl8188fu"
echo ""
