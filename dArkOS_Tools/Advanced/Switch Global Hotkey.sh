#!/bin/bash
# Switch Global Hotkey Tool for dArkOS
# Allows interactive button detection (press any button) or selecting presets

sudo chmod 666 /dev/tty1 2>/dev/null
export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

height="16"
width="58"

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

start_controls() {
  if [[ -z $(pgrep -f gptokeyb) ]]; then
    sudo chmod 666 /dev/uinput 2>/dev/null
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    /opt/inttools/gptokeyb -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
    disown
    set_gptokeyb="Y"
  fi
}

stop_controls() {
  if [[ ! -z "$set_gptokeyb" ]] || [[ ! -z $(pgrep -f gptokeyb) ]]; then
    pgrep -f gptokeyb | sudo xargs kill -9 2>/dev/null
    unset SDL_GAMECONTROLLERCONFIG_FILE
  fi
}

clean_exit() {
  printf "\033c" > /dev/tty1
  stop_controls
  exit 0
}

# Start controls on script launch
start_controls

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
  elif [ ! -z "$ra_hk" ]; then
    echo "Button $ra_hk"
  else
    echo "Not Set"
  fi
}

apply_hotkey() {
  local btn_id="$1"
  local btn_name="$2"
  local ogage_code="$3"   # e.g. 0x2c4, 0x2c0, 0x2c3

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
  if [ -f "/usr/local/bin/ogage" ] && [ ! -z "$ogage_code" ]; then
    python3 -c "
import os, subprocess

src = '/usr/local/bin/ogage'
target_code = int('$ogage_code', 16)

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

  dialog --msgbox "\nHotkey successfully configured!\n\nNew Hotkey: $btn_name\nButton ID: $btn_id\n\n- In-game: $btn_name + X (Menu), $btn_name + START (Exit)\n- Brightness: $btn_name + VOL UP / DOWN" 12 $width > /dev/tty1
}

detect_interactive() {
  # Stop gptokeyb so raw button press can be caught
  stop_controls

  dialog --infobox "\n--- Press Desired Hotkey Button ---\n\nPlease press the button on your console\nthat you want to use as the Hotkey\n(e.g. FN, SELECT, MENU, R3)...\n\nWaiting up to 15 seconds..." 10 $width > /dev/tty1

  DETECT_JSON="/tmp/detected_hotkey.json"
  rm -f "$DETECT_JSON"

  python3 -c "
import sys, os, time, select, json
from evdev import InputDevice, list_devices, ecodes

OUT_FILE = '$DETECT_JSON'

def detect():
    devs = []
    for path in list_devices():
        try:
            d = InputDevice(path)
            if ecodes.EV_KEY in d.capabilities():
                devs.append(d)
        except Exception:
            pass
    if not devs:
        sys.exit(1)

    dev_map = {d.fd: d for d in devs}
    start = time.time()
    while time.time() - start < 15:
        r, _, _ = select.select(list(dev_map.keys()), [], [], 0.1)
        for fd in r:
            dev = dev_map[fd]
            for ev in dev.read():
                if ev.type == ecodes.EV_KEY and ev.value == 1:
                    code = ev.code
                    caps = dev.capabilities()
                    keys = caps.get(ecodes.EV_KEY, [])
                    btn_keys = [k for k in sorted(keys) if isinstance(k, int) and (k >= 0x100 or 'gamepad' in dev.name.lower() or 'joypad' in dev.name.lower())]
                    btn_id = btn_keys.index(code) if code in btn_keys else code

                    raw = ecodes.KEY.get(code, ecodes.BTN.get(code, f'KEY_{code}'))
                    if isinstance(raw, (list, tuple)):
                        raw = raw[0]

                    if code == 708 or btn_id == 16:
                        name = 'FN Button'
                    elif code == 704 or btn_id == 12:
                        name = 'SELECT Button'
                    elif code == 705 or btn_id == 13:
                        name = 'START Button'
                    elif code == 707 or btn_id == 15:
                        name = 'R3 Button (Right Stick Click)'
                    elif code == 706 or btn_id == 14:
                        name = 'L3 Button (Left Stick Click)'
                    else:
                        name = str(raw)

                    res = {'button_id': str(btn_id), 'button_name': name, 'hex_code': hex(code), 'device': dev.name}
                    with open(OUT_FILE, 'w') as f:
                        json.dump(res, f)
                    sys.exit(0)
    sys.exit(2)
detect()
"
  status=$?

  # Restart controls for navigation
  start_controls

  if [ $status -ne 0 ] || [ ! -f "$DETECT_JSON" ]; then
    dialog --msgbox "\nNo button press was detected (Timeout).\nPlease try again." 7 $width > /dev/tty1
    return
  fi

  detected_id=$(python3 -c "import json; d=json.load(open('$DETECT_JSON')); print(d['button_id'])" 2>/dev/null)
  detected_name=$(python3 -c "import json; d=json.load(open('$DETECT_JSON')); print(d['button_name'])" 2>/dev/null)
  detected_hex=$(python3 -c "import json; d=json.load(open('$DETECT_JSON')); print(d['hex_code'])" 2>/dev/null)
  detected_dev=$(python3 -c "import json; d=json.load(open('$DETECT_JSON')); print(d['device'])" 2>/dev/null)

  dialog --yesno "\nDetected Button:\n  Name: $detected_name\n  Button ID: $detected_id\n  Linux Code: $detected_hex\n  Device: $detected_dev\n\nSet this button as your Global Hotkey?" 12 $width > /dev/tty1
  if [ $? -eq 0 ]; then
    apply_hotkey "$detected_id" "$detected_name" "$detected_hex"
  fi
}

while true; do
  cur_hk=$(get_current_hotkey_name)
  
  options=(
    1 "Press a button to set as Hotkey (Interactive Detect)"
    2 "Set to FN Button (Button 16 - R36S Default)"
    3 "Set to SELECT Button (Button 12 - ArkOS Classic)"
    4 "Set to R3 Button (Button 15 - Right Stick Click)"
    5 "Exit"
  )

  selection=(dialog \
    --backtitle "dArkOS Global Hotkey Manager" \
    --title "Current Hotkey: $cur_hk" \
    --no-collapse \
    --clear \
    --cancel-label "Exit" \
    --menu "Select Hotkey Configuration:" $height $width 15)

  choice=$("${selection[@]}" "${options[@]}" 2>&1 > /dev/tty1)
  if [ $? -ne 0 ]; then
    clean_exit
  fi

  case $choice in
    1) detect_interactive ;;
    2) apply_hotkey "16" "FN Button (Button 16)" "0x2c4" ;;
    3) apply_hotkey "12" "SELECT Button (Button 12)" "0x2c0" ;;
    4) apply_hotkey "15" "R3 Button (Button 15)" "0x2c3" ;;
    5) clean_exit ;;
  esac
done
