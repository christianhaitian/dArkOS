#!/bin/bash
# Low Battery Suspend Configuration Tool for dArkOS
# Manages automatic suspend when battery drops below safety threshold

sudo chmod 666 /dev/tty1 2>/dev/null
export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

height="15"
width="55"

if compgen -G "/boot/rk3566*" > /dev/null; then
  if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
  then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
  else
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
  fi
  height="20"
  width="60"
else
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz 2>/dev/null || sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

# Controls for dialog
if [[ -z $(pgrep -f gptokeyb) ]]; then
  sudo chmod 666 /dev/uinput 2>/dev/null
  export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
  /opt/inttools/gptokeyb -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
  disown
  set_gptokeyb="Y"
fi

clean_exit() {
  printf "\033c" > /dev/tty1
  if [[ ! -z "$set_gptokeyb" ]] || [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null
    unset SDL_GAMECONTROLLERCONFIG_FILE
  fi
  exit 0
}

CONF="/home/ark/.config/.LOWBATT"
PROG="/usr/local/bin/lowbatt_suspend.sh"
UNIT="/etc/systemd/system/lowbatt-suspend.service"

get_status() {
  if systemctl is-active --quiet lowbatt-suspend.service 2>/dev/null; then
    local thr
    thr=$(cat "$CONF" 2>/dev/null | tr -dc '0-9')
    [ -z "$thr" ] && thr=5
    echo "Active (Threshold: ${thr}%)"
  else
    echo "Disabled"
  fi
}

install_daemon() {
  local thr="$1"
  dialog --infobox "\nConfiguring Low Battery Suspend (${thr}%)...\nPlease wait..." 6 $width > /dev/tty1

  echo "$thr" > "$CONF"
  chown ark:ark "$CONF" 2>/dev/null

  sudo tee "$PROG" > /dev/null <<'EOF'
#!/bin/bash
# Suspend console when battery drops below threshold and not charging.
CONF=/home/ark/.config/.LOWBATT
CAP=/sys/class/power_supply/battery/capacity
INTERVAL=30
NEEDED=3

low_count=0

read_threshold() {
  local t
  t=$(cat "$CONF" 2>/dev/null | tr -dc '0-9')
  [ -z "$t" ] && t=5
  [ "$t" -lt 1 ] && t=1
  [ "$t" -gt 50 ] && t=50
  echo "$t"
}

is_charging() {
  grep -qi "charging" /sys/class/power_supply/*/status 2>/dev/null || \
  grep -q "1" /sys/class/power_supply/*/online 2>/dev/null
}

while true; do
  sleep "$INTERVAL"
  [ -r "$CAP" ] || continue

  cap=$(cat "$CAP" 2>/dev/null | tr -dc '0-9')
  [ -z "$cap" ] && continue

  if is_charging; then
    low_count=0
    continue
  fi

  thr=$(read_threshold)
  if [ "$cap" -le "$thr" ]; then
    low_count=$((low_count+1))
    logger -t lowbatt "battery ${cap}%, threshold ${thr}%, count ${low_count}/${NEEDED}"
    if [ "$low_count" -ge "$NEEDED" ]; then
      logger -t lowbatt "suspending console at ${cap}% battery"
      sync
      /bin/systemctl suspend
      low_count=0
      sleep 120
    fi
  else
    low_count=0
  fi
done
EOF
  sudo chmod +x "$PROG"

  sudo tee "$UNIT" > /dev/null <<'EOF'
[Unit]
Description=Suspend on low battery
After=multi-user.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/lowbatt_suspend.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable lowbatt-suspend.service > /dev/null 2>&1
  sudo systemctl restart lowbatt-suspend.service

  dialog --msgbox "\nLow Battery Suspend enabled!\n\n- Threshold: ${thr}%\n- Checks every 30s (triggers after 3 readings)\n- Automatically suspends console safely to prevent abrupt power loss" 10 $width > /dev/tty1
}

disable_daemon() {
  dialog --infobox "\nDisabling Low Battery Suspend...\nPlease wait..." 5 $width > /dev/tty1
  sudo systemctl disable --now lowbatt-suspend.service > /dev/null 2>&1
  sudo rm -f "$UNIT" "$PROG"
  sudo systemctl daemon-reload
  dialog --msgbox "\nLow Battery Suspend has been disabled." 7 $width > /dev/tty1
}

test_suspend() {
  dialog --yesno "\nWould you like to test instant suspend now?\n\nPress Power button to wake the console." 8 $width > /dev/tty1
  if [ $? -eq 0 ]; then
    sync
    sudo systemctl suspend
  fi
}

while true; do
  cur_stat=$(get_status)
  
  options=(
    1 "Enable / Set Threshold to 5% (Recommended)"
    2 "Enable / Set Threshold to 10%"
    3 "Enable / Set Threshold to 15%"
    4 "Disable Low Battery Suspend"
    5 "Test Suspend Now (Instant Sleep)"
    6 "Exit"
  )

  selection=(dialog \
    --backtitle "dArkOS Low Battery Protection" \
    --title "Status: $cur_stat" \
    --no-collapse \
    --clear \
    --cancel-label "Exit" \
    --menu "Select an option:" $height $width 15)

  choice=$("${selection[@]}" "${options[@]}" 2>&1 > /dev/tty1)
  if [ $? -ne 0 ]; then
    clean_exit
  fi

  case $choice in
    1) install_daemon 5 ;;
    2) install_daemon 10 ;;
    3) install_daemon 15 ;;
    4) disable_daemon ;;
    5) test_suspend ;;
    6) clean_exit ;;
  esac
done
