#!/bin/bash

if grep -qs "SDIO_ID=024C:D723" /sys/bus/sdio/devices/*/uevent; then
  if ! cmp -s /usr/local/bin/rgb30dtbs/rk3566-rgb20sx.dtb /boot/rk3566-rgb30.dtb; then
    sudo cp -f /usr/local/bin/rgb30dtbs/rk3566-rgb20sx.dtb /boot/rk3566-rgb30.dtb
  fi
  exit 0
fi

if test -z "$(dmesg | grep vdd_cpu | tr -d '\0')"
then
  if [ ! -f "/home/ark/.config/.V2DTBLOADED" ]; then
    sudo cp -f /usr/local/bin/rgb30dtbs/rk3566-rgb30.dtb.v2 /boot/rk3566-rgb30.dtb
    touch /home/ark/.config/.V2DTBLOADED
  else
    sudo cp -f /usr/local/bin/rgb30dtbs/rk3566-rgb30.dtb.v1 /boot/rk3566-rgb30.dtb
    rm -f /home/ark/.config/.V2DTBLOADED
  fi
fi