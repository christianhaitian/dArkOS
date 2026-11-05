#!/bin/bash
# Low Battery Suspend Configuration Tool for dArkOS with i18n support
# Manages automatic suspend when battery drops below safety threshold

sudo chmod 666 /dev/tty1 2>/dev/null
export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

height="15"
width="58"

if compgen -G "/boot/rk3566*" > /dev/null; then
  if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
  then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
  else
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
  fi
  height="20"
  width="66"
else
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz 2>/dev/null || sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

# Detect system / EmulationStation language
get_language() {
  local lang
  if [ -f "/home/ark/.emulationstation/es_settings.cfg" ]; then
    lang=$(grep '<string name="Language"' /home/ark/.emulationstation/es_settings.cfg 2>/dev/null | sed -n 's/.*value="\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')
  fi
  if [ -z "$lang" ] && [ -f "/home/ark/.config/.LANGUAGE" ]; then
    lang=$(cat /home/ark/.config/.LANGUAGE 2>/dev/null | tr -dc 'a-zA-Z_' | tr '[:upper:]' '[:lower:]')
  fi
  [ -z "$lang" ] && lang="${LANG:0:2}"
  [ -z "$lang" ] && lang="en"
  echo "${lang:0:2}"
}

LANG_CODE=$(get_language)

# i18n Strings
case "$LANG_CODE" in
  pl)
    T_TITLE="Ochrona Baterii dArkOS"
    T_STATUS_LABEL="Status"
    T_ACTIVE="Aktywna (Prog: %s%%)"
    T_DISABLED="Wylaczona"
    T_MENU="Wybierz opcje ochrony baterii:"
    T_OPT_5="1. Wlacz / Ustaw prog na 5% (Zalecane)"
    T_OPT_10="2. Wlacz / Ustaw prog na 10%"
    T_OPT_15="3. Wlacz / Ustaw prog na 15%"
    T_OPT_DIS="4. Wylacz usypianie przy niskiej baterii"
    T_OPT_TEST="5. Testuj usypianie teraz (Natychmiastowy sen)"
    T_OPT_EXIT="6. Wyjscie"
    T_EXIT_BTN="Wyjscie"
    T_CONFIGURING="Konfigurowanie usypiania przy niskiej baterii (%s%%)...\nProsze czekac..."
    T_ENABLED_MSG="Usypianie przy niskiej baterii zostalo wlaczone!\n\n- Prog: %s%%\n- Sprawdzanie co 30s (po 3 niskich odczytach)\n- Automatycznie usypia konsole, chroniac przed naglym rozladowaniem"
    T_DISABLING="Wylaczanie ochrony baterii...\nProsze czekac..."
    T_DISABLED_MSG="Usypianie przy niskiej baterii zostalo wylaczone."
    T_TEST_PROMPT="Czy chcesz przetestowac natychmiastowe usypianie?\n\nAby wybudzic konsole, nacisnij przycisk POWER."
    ;;
  *)
    T_TITLE="dArkOS Low Battery Protection"
    T_STATUS_LABEL="Status"
    T_ACTIVE="Active (Threshold: %s%%)"
    T_DISABLED="Disabled"
    T_MENU="Select battery protection option:"
    T_OPT_5="1. Enable / Set Threshold to 5% (Recommended)"
    T_OPT_10="2. Enable / Set Threshold to 10%"
    T_OPT_15="3. Enable / Set Threshold to 15%"
    T_OPT_DIS="4. Disable Low Battery Suspend"
    T_OPT_TEST="5. Test Suspend Now (Instant Sleep)"
    T_OPT_EXIT="6. Exit"
    T_EXIT_BTN="Exit"
    T_CONFIGURING="Configuring Low Battery Suspend (%s%%)...\nPlease wait..."
    T_ENABLED_MSG="Low Battery Suspend enabled!\n\n- Threshold: %s%%\n- Checks every 30s (triggers after 3 readings)\n- Automatically suspends console safely to prevent abrupt power loss"
    T_DISABLING="Disabling Low Battery Suspend...\nPlease wait..."
    T_DISABLED_MSG="Low Battery Suspend has been disabled."
    T_TEST_PROMPT="Would you like to test instant suspend now?\n\nPress Power button to wake the console."
    ;;
esac

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
    printf "$T_ACTIVE" "$thr"
  else
    echo "$T_DISABLED"
  fi
}

install_daemon() {
  local thr="$1"
  local info_msg
  info_msg=$(printf "$T_CONFIGURING" "$thr")
  dialog --infobox "\n$info_msg" 6 $width > /dev/tty1

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
      # Play voice warning and suspend immediately when finished
      /usr/local/bin/speak_bat_life.sh critical_suspend
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

  local succ_msg
  succ_msg=$(printf "$T_ENABLED_MSG" "$thr")
  dialog --msgbox "\n$succ_msg" 10 $width > /dev/tty1
}

disable_daemon() {
  dialog --infobox "\n$T_DISABLING" 5 $width > /dev/tty1
  sudo systemctl disable --now lowbatt-suspend.service > /dev/null 2>&1
  sudo rm -f "$UNIT" "$PROG"
  sudo systemctl daemon-reload
  dialog --msgbox "\n$T_DISABLED_MSG" 7 $width > /dev/tty1
}

test_suspend() {
  dialog --yesno "\n$T_TEST_PROMPT" 8 $width > /dev/tty1
  if [ $? -eq 0 ]; then
    sync
    sudo systemctl suspend
  fi
}

while true; do
  cur_stat=$(get_status)
  
  options=(
    1 "$T_OPT_5"
    2 "$T_OPT_10"
    3 "$T_OPT_15"
    4 "$T_OPT_DIS"
    5 "$T_OPT_TEST"
    6 "$T_OPT_EXIT"
  )

  selection=(dialog \
    --backtitle "$T_TITLE" \
    --title "$T_STATUS_LABEL: $cur_stat" \
    --no-collapse \
    --clear \
    --cancel-label "$T_EXIT_BTN" \
    --menu "$T_MENU" $height $width 15)

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
