#!/bin/bash
# USB ethernet gadget (CDC ECM) for the SOLIS deploy link.
# Replicates the stock ArkOS tools/USB-Network.sh setup, but at every boot:
# the Mac sees "g350 Console" as a network interface; device is 192.168.7.1,
# set the Mac side to 192.168.7.2/24, then: ssh ark@192.168.7.1
# Kernel: dwc2 dual-role (autoloaded via DT) + libcomposite/usb_f_ecm modules.
set -e
modprobe libcomposite
modprobe usb_f_ecm

# No UDC = the DTB booted the port in host role (see usbmode.sh) — nothing to do.
if [ -z "$(ls /sys/class/udc 2>/dev/null)" ]; then
  echo "usbnet: no UDC — USB-C is in host mode; run 'usbmode.sh gadget' for the deploy link"
  exit 0
fi

G=/sys/kernel/config/usb_gadget/g350dev
[ -d "$G" ] && exit 0   # already configured (service re-run)

mkdir -p "$G"
cd "$G"
echo 0x1d6b > idVendor    # Linux Foundation
echo 0x0104 > idProduct   # Multifunction composite gadget
mkdir -p strings/0x409
echo "SOLIS" > strings/0x409/manufacturer
echo "g350 Console" > strings/0x409/product
echo "g350-solis" > strings/0x409/serialnumber
mkdir -p configs/c.1/strings/0x409
echo "ECM" > configs/c.1/strings/0x409/configuration
mkdir -p functions/ecm.usb0
echo "02:1d:6b:53:01:01" > functions/ecm.usb0/host_addr
echo "02:1d:6b:53:01:02" > functions/ecm.usb0/dev_addr
ln -sf functions/ecm.usb0 configs/c.1/
ls /sys/class/udc | head -n1 > UDC

ip addr add 192.168.7.1/24 dev usb0
ip link set usb0 up
