#!/bin/bash

# Standalone RTL8188FU driver builder for existing dArkOS installations
# This script cross-compiles the driver and creates an installation package

set -e

echo "=== RTL8188FU Standalone Driver Builder ==="
echo ""

# Check if kernel source is available
if [ ! -d "main" ]; then
  echo "Error: Kernel source not found. Please run this from the dArkOS build directory."
  echo "Or run: git clone --recursive --depth=1 https://github.com/christianhaitian/RG353VKernel.git main"
  exit 1
fi

# Get kernel version from kernel source
cd main
KERNEL_VERSION=$(make kernelversion)
cd ..

echo "Kernel version: ${KERNEL_VERSION}"

# Clone RTL8188FU driver if not present
DRIVER_SRC=rtl8188fu
if [ ! -d "$DRIVER_SRC" ]; then
  echo "Cloning RTL8188FU driver..."
  git clone --depth=1 https://github.com/kelebek333/rtl8188fu.git $DRIVER_SRC
fi

cd $DRIVER_SRC

# Clean previous builds
make clean 2>/dev/null || true

# Build the driver
echo "Building RTL8188FU driver..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- KSRC=../main -j$(nproc)

if [ ! -f "rtl8188fu.ko" ]; then
  echo "Error: Driver compilation failed!"
  exit 1
fi

echo "Driver compiled successfully!"

# Create installation package
cd ..
PACKAGE_DIR="rtl8188fu_install_package"
rm -rf $PACKAGE_DIR
mkdir -p $PACKAGE_DIR

# Copy the compiled module
cp $DRIVER_SRC/rtl8188fu.ko $PACKAGE_DIR/

# Create installation script
cat > $PACKAGE_DIR/install.sh << 'INSTALLEOF'
#!/bin/bash

# RTL8188FU WiFi Driver Installation Script for dArkOS
# Run this script as root on your R36S device

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "=== Installing RTL8188FU WiFi Driver ==="

# Get current kernel version
KERNEL_VERSION=$(uname -r)
echo "Kernel version: ${KERNEL_VERSION}"

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

# Try to load the module (if USB adapter is connected)
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
echo "To verify the driver is loaded, run: lsmod | grep rtl8188fu"
echo "To see kernel messages: dmesg | grep rtl8188fu"
echo ""

INSTALLEOF

chmod +x $PACKAGE_DIR/install.sh

# Create README
cat > $PACKAGE_DIR/README.txt << 'READMEEOF'
RTL8188FU WiFi Driver Installation Package for dArkOS
======================================================

This package adds support for Realtek RTL8188FTV/RTL8188FU USB WiFi adapters
(VID:0bda PID:f179) to your existing dArkOS installation.

INSTALLATION INSTRUCTIONS:
--------------------------

1. Copy this entire folder to your R36S device
   (Use SSH, USB transfer, or SD card)

2. On your R36S, open a terminal and navigate to this folder

3. Run the installation script as root:
   sudo ./install.sh

4. Connect your RTL8188FU USB WiFi adapter

5. The WiFi interface should appear automatically

VERIFICATION:
-------------

Check if the driver is loaded:
  lsmod | grep rtl8188fu

View kernel messages:
  dmesg | grep rtl8188fu

Check network interfaces:
  ip link show

TROUBLESHOOTING:
----------------

If WiFi doesn't appear:
- Unplug and reconnect the USB adapter
- Check if the driver loaded: lsmod | grep rtl8188fu
- Manually load the driver: sudo modprobe rtl8188fu
- Check USB device: lsusb (should show 0bda:f179)

If still not working:
- Reboot the device
- Check dmesg for errors: dmesg | tail -50

UNINSTALLATION:
---------------

To remove the driver:
  sudo modprobe -r rtl8188fu
  sudo rm /lib/modules/$(uname -r)/kernel/drivers/net/wireless/realtek/rtl8188fu/rtl8188fu.ko
  sudo rm /etc/modprobe.d/rtl8188fu.conf
  sudo depmod -a

READMEEOF

# Create a tarball
echo "Creating installation package..."
tar czf rtl8188fu_install_package.tar.gz $PACKAGE_DIR/

echo ""
echo "=== Package Created Successfully! ==="
echo ""
echo "Installation package: rtl8188fu_install_package.tar.gz"
echo "Package folder: $PACKAGE_DIR/"
echo ""
echo "To install on your R36S:"
echo "1. Copy rtl8188fu_install_package.tar.gz to your R36S"
echo "2. Extract: tar xzf rtl8188fu_install_package.tar.gz"
echo "3. cd rtl8188fu_install_package"
echo "4. sudo ./install.sh"
echo ""
