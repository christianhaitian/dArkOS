#!/bin/bash
# ======================================================================================== #
# Created by Christian Haitian with inspiration from                                       #
# https://github.com/lcdyk0517/dArkOS-3562/raw/refs/heads/main/rootfs/usr/local/bin/ps2.sh #
# ======================================================================================== #

ROM="${2:-}"
DIRECTORY=$(dirname "$2" | cut -d "/" -f2)
DATA=/${DIRECTORY}/ps2/armsx2
APP=/opt/armsx2/armsx2-sdl
DEVICE="$(tr -d '\0' < /home/ark/.config/.DEVICE 2>/dev/null)"

[ -x "$APP" ] || { echo "PS2: missing $APP"; sleep 5; exit 1; }

if [[ "$(free -m | awk '/^Mem:/{print $2}')" -lt "1900" ]]; then
  if [[ -z "$(zramctl)" ]]; then
    printf "Enabling zram.  Please wait...\n" >> /dev/tty1
    sudo modprobe zram num_devices=1
    echo lz4 | sudo tee /sys/block/zram0/comp_algorithm
    echo 1G | sudo tee /sys/block/zram0/disksize
    sudo mkswap /dev/zram0
    sudo swapon /dev/zram0 -p 100
    printf "Launching dolphin emulation now" >> /dev/tty1
  fi
fi

mkdir -p "$DATA"/{inis,memcards,sstates,snaps,cache,textures,cheats,patches,resources,logs,inputprofiles,debuggerlayouts,debuggersettings} "$DATA/.config/ARMSX2/inis"

INI="$DATA/.config/ARMSX2/inis/PCSX2.ini"
if [ ! -f "$INI" ] \
   || ! grep -q '^SettingsVersion[[:space:]]*=' "$INI" 2>/dev/null \
   || grep -qE '^Renderer[[:space:]]*=[[:space:]]*-1[[:space:]]*$' "$INI" 2>/dev/null \
   || ! grep -qE "^Bios[[:space:]]*=[[:space:]]*/${DIRECTORY}/bios[[:space:]]*$" "$INI" 2>/dev/null; then
  cp -f /opt/armsx2/PCSX2.ini.template "$INI"
  if [[ $DEVICE == "MINILOONG" ]]; then
    sed -i 's/Back \& SDL-0/Guide \& SDL-0/g' "$INI"
  fi
fi

BIOS_DIR=/${DIRECTORY}/bios
sed -i "s|^Bios = .*|Bios = $BIOS_DIR|" "$INI"

sed -i -E 's|^Renderer = .*|Renderer = 14|' "$INI"

if [[ $DEVICE == "MINILOONG" ]]; then

  # Detect HDMI connection
  for status in /sys/class/drm/card*-HDMI-A-*/status; do
    [ -e "$status" ] || continue
    if grep -q disconnected "$status"; then
      sed -i -E 's|^DisplayRotation = .*|DisplayRotation = 270|' "$INI"
      break
    else
      sed -i -E 's|^DisplayRotation = .*|DisplayRotation = 0|' "$INI"
      break
    fi
  done

fi

case "${ROM##*.}" in
  cue|CUE)
    _bn=$(sed -n 's/^FILE "\(.*\)" BINARY.*/\1/p' "$ROM" 2>/dev/null | head -1)
    if [ -n "$_bn" ] && [ "$(grep -c '^[[:space:]]*TRACK' "$ROM" 2>/dev/null)" = "1" ] \
       && [ -f "$(dirname "$ROM")/$_bn" ]; then
      ROM="$(dirname "$ROM")/$_bn"
    fi
    ;;
esac

export HOME="$DATA"
export XDG_CONFIG_HOME="$DATA/.config"
export XDG_DATA_HOME="$DATA/.local/share"
export SDL_GAMECONTROLLERCONFIG="19009b4d4b4800000111000000010000,retrogame_joypad,a:b0,b:b1,x:b2,y:b3,back:b8,guide:b10,start:b9,leftstick:b11,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:b13,dpdown:b14,dpleft:b15,dpright:b16,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b6,righttrigger:b7,crc:4d9b,platform:Linux,"
export SDL_AUDIODRIVER=alsa
export AUDIODEV=default

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export VK_ICD_FILENAMES=/opt/malisx2/malisx2.json

LOG="$DATA/logs/last_run.log"
echo "VAR=armsx2" > /home/ark/.config/KILLIT
sudo systemctl restart killer_daemon.service

nice -n -19 "$APP" --fullscreen-mode 640x480 ${ROM:+"$ROM"} > "$LOG" 2>&1

sudo systemctl stop killer_daemon.service
sync
