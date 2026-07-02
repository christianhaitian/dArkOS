#!/bin/bash
# Switch the G350's USB-C role (single PHY — one role per boot, set in the DTB).
#   usbmode.sh gadget -> SSH deploy link, device = 192.168.7.1  (image default)
#   usbmode.sh host   -> USB drives / MIDI keyboards / wifi dongles
# Also switchable from any computer: on the BOOT (FAT32) partition, copy
# rk3326-g350-linux.dtb.host or .gadget over rk3326-g350-linux.dtb.
DTB=/boot/rk3326-g350-linux.dtb
case "$1" in
  host|gadget) sudo cp ${DTB}.$1 ${DTB} && sync ;;
  *) echo "usage: usbmode.sh host|gadget   (reboots to apply)"; exit 1 ;;
esac
echo "USB-C role set to $1 — rebooting"
sudo reboot
