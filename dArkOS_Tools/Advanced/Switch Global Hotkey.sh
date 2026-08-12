#!/bin/bash
# Switch Global Hotkey Tool for dArkOS
# Allows switching hotkey between FN (Button 16), SELECT (Button 12), and R3 (Button 15)

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

# Kill old gptokeyb instances and start controls for dialog
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

# Determine current hotkey
get_current_hotkey_name() {
  local ra_hk
  ra_hk=$(grep "^input_enable_hotkey_btn" /home/ark/.config/retroarch/retroarch.cfg 2>/dev/null | cut -d '"' -f 2)
  if [ "$ra_hk" == "16" ]; then
    echo "FN Button (Button 16)"
  elif [ "$ra_hk" == "12" ]; then
    echo "SELECT Button (Button 12)"
  elif [ "$ra_hk" == "15" ]; then
    echo "R3 Button (Button 15)"
  else
    echo "Custom (Button $ra_hk)"
  fi
}

apply_hotkey() {
  local btn_id="$1"
  local btn_name="$2"
  local ogage_code="$3"   # 0x2c4 for FN, 0x2c0 for SELECT, 0x2c3 for R3

  dialog --infobox "\nSetting Hotkey to $btn_name...\nPlease wait..." 6 $width > /dev/tty1

  # 1. Update RetroArch and RetroArch32 configs
  for rcfg in /home/ark/.config/retroarch/retroarch.cfg /home/ark/.config/retroarch32/retroarch.cfg; do
    if [ -f "$rcfg" ]; then
      sed -i "s/^input_enable_hotkey_btn = .*/input_enable_hotkey_btn = \"$btn_id\"/" "$rcfg"
    fi
  done

  # 2. Update EmulationStation input configs
  for es_cfg in /etc/emulationstation/es_input.cfg /home/ark/.emulationstation/es_input.cfg; do
    if [ -f "$es_cfg" ]; then
      sed -i "s/<input name=\"system_hk\" type=\"button\" id=\"[0-9]*\" value=\"1\" \/>/<input name=\"system_hk\" type=\"button\" id=\"$btn_id\" value=\"1\" \/>/" "$es_cfg"
      sed -i "s/<input name=\"hotkeyenable\" type=\"button\" id=\"[0-9]*\" value=\"1\" \/>/<input name=\"hotkeyenable\" type=\"button\" id=\"$btn_id\" value=\"1\" \/>/" "$es_cfg"
      sed -i "s/<input name=\"hotkey\" type=\"button\" id=\"[0-9]*\" value=\"1\" \/>/<input name=\"hotkey\" type=\"button\" id=\"$btn_id\" value=\"1\" \/>/" "$es_cfg"
    fi
  done

  # 3. Patch ogage binary for brightness modifier
  if [ -f "/usr/local/bin/ogage" ]; then
    python3 -c "
import os, subprocess

src = '/usr/local/bin/ogage'
target_code = int('$ogage_code', 16) # e.g. 0x2c4, 0x2c0, 0x2c3

with open(src, 'rb') as f:
    data = bytearray(f.read())

candidates = [
    bytes([0x1f, 0x01, 0x0b, 0x71]), # 0x2c0 (SELECT)
    bytes([0x1f, 0x0d, 0x0b, 0x71]), # 0x2c3 (R3)
    bytes([0x1f, 0x11, 0x0b, 0x71])  # 0x2c4 (FN)
]

new_imm12 = target_code & 0xfff
new_val = 0x7100001f | (new_imm12 << 10) | (8 << 5) | 31
new_bytes = new_val.to_bytes(4, 'little')

count = 0
for cand in candidates:
    idx = 0
    while True:
        pos = data.find(cand, idx)
        if pos == -1:
            break
        data[pos:pos+4] = new_bytes
        count += 1
        idx = pos + 4

if count > 0:
    with open('/tmp/ogage_patched', 'wb') as f:
        f.write(data)
    os.chmod('/tmp/ogage_patched', 0o755)
    subprocess.run(['sudo', 'systemctl', 'stop', 'ogage.service'], check=True)
    subprocess.run(['sudo', 'cp', '/tmp/ogage_patched', src], check=True)
    subprocess.run(['sudo', 'chmod', '755', src], check=True)
    subprocess.run(['sudo', 'systemctl', 'start', 'ogage.service'], check=True)
" 2>/dev/null
  fi

  # 4. Restart EmulationStation
  sudo systemctl restart emulationstation > /dev/null 2>&1

  dialog --msgbox "\nHotkey successfully changed to:\n$btn_name\n\n- In-game: $btn_name + X (Menu), $btn_name + START (Exit)\n- Brightness: $btn_name + VOL UP / DOWN" 10 $width > /dev/tty1
}

while true; do
  cur_hk=$(get_current_hotkey_name)
  
  options=(
    1 "Set Hotkey to FN Button (Button 16 - R36S Default)"
    2 "Set Hotkey to SELECT Button (Button 12 - ArkOS Classic)"
    3 "Set Hotkey to R3 Button (Button 15 - Right Stick Click)"
    4 "Exit"
  )

  selection=(dialog \
    --backtitle "dArkOS Global Hotkey Switcher" \
    --title "Current Hotkey: $cur_hk" \
    --no-collapse \
    --clear \
    --cancel-label "Exit" \
    --menu "Select your desired Hotkey:" $height $width 15)

  choice=$("${selection[@]}" "${options[@]}" 2>&1 > /dev/tty1)
  if [ $? -ne 0 ]; then
    clean_exit
  fi

  case $choice in
    1) apply_hotkey "16" "FN Button (Button 16)" "0x2c4" ;;
    2) apply_hotkey "12" "SELECT Button (Button 12)" "0x2c0" ;;
    3) apply_hotkey "15" "R3 Button (Button 15)" "0x2c3" ;;
    4) clean_exit ;;
  esac
done
