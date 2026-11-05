#!/usr/bin/env python3
import sys, os, time, select, json
from evdev import InputDevice, list_devices, ecodes

OUT_FILE = "/tmp/detected_hotkey.json"

def get_gamepad_devices():
    devs = []
    for path in list_devices():
        try:
            dev = InputDevice(path)
            caps = dev.capabilities()
            if ecodes.EV_KEY in caps:
                devs.append(dev)
        except Exception:
            pass
    return devs

def detect_button(timeout_sec=15):
    devices = get_gamepad_devices()
    if not devices:
        print("ERROR: No input devices found.")
        sys.exit(1)

    dev_map = {dev.fd: dev for dev in devices}
    start_time = time.time()

    while time.time() - start_time < timeout_sec:
        r, _, _ = select.select(list(dev_map.keys()), [], [], 0.2)
        for fd in r:
            dev = dev_map[fd]
            for event in dev.read():
                if event.type == ecodes.EV_KEY and event.value == 1: # Key press
                    code = event.code
                    caps = dev.capabilities()
                    keys = caps.get(ecodes.EV_KEY, [])
                    btn_keys = [k for k in sorted(keys) if isinstance(k, int) and (k >= 0x100 or 'gamepad' in dev.name.lower() or 'joypad' in dev.name.lower())]
                    
                    if code in btn_keys:
                        btn_id = btn_keys.index(code)
                    else:
                        btn_id = code # fallback

                    raw_name = ecodes.KEY.get(code, ecodes.BTN.get(code, f"CODE_{code}"))
                    if isinstance(raw_name, (list, tuple)):
                        raw_name = raw_name[0]

                    # User-friendly label
                    if code == 708 or btn_id == 16:
                        display_name = f"FN Button (ID: {btn_id})"
                    elif code == 704 or btn_id == 12:
                        display_name = f"SELECT Button (ID: {btn_id})"
                    elif code == 705 or btn_id == 13:
                        display_name = f"START Button (ID: {btn_id})"
                    elif code == 707 or btn_id == 15:
                        display_name = f"R3 Button (Right Stick Click, ID: {btn_id})"
                    elif code == 706 or btn_id == 14:
                        display_name = f"L3 Button (Left Stick Click, ID: {btn_id})"
                    else:
                        display_name = f"{raw_name} (ID: {btn_id})"

                    result = {
                        "device_name": dev.name,
                        "device_path": dev.path,
                        "keycode": code,
                        "hex_code": f"0x{code:x}",
                        "button_id": btn_id,
                        "button_name": display_name,
                        "raw_name": str(raw_name)
                    }

                    with open(OUT_FILE, 'w', encoding='utf-8') as f:
                        json.dump(result, f, indent=2)

                    print(f"SUCCESS: Captured {display_name} on {dev.name}")
                    return result

    print("TIMEOUT: No button pressed within time limit.")
    sys.exit(2)

if __name__ == '__main__':
    detect_button(15)
