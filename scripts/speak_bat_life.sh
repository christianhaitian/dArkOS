#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

. /usr/local/bin/buttonmon.sh 2>/dev/null

if [ -e "/home/ark/.config/.MBROLA_VOICE_FEMALE" ]; then
  voice="1"
elif [ -e "/home/ark/.config/.MBROLA_VOICE_MALE3" ]; then
  voice="3"
else
  voice="2"
fi

speak() {
  local msg="$1"
  if [ "$(id -u)" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
    runuser -u ark -- espeak-ng -vmb-us${voice} -s130 "$msg" 2>/dev/null || espeak-ng -s130 "$msg" 2>/dev/null
  else
    espeak-ng -vmb-us${voice} -s130 "$msg" 2>/dev/null || espeak-ng -s130 "$msg" 2>/dev/null
  fi
}

if [ -f "/boot/rk3326-rg351v-linux.dtb" ] || [ -f "/boot/rk3326-gameforce-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ]; then
  Test_Button_R1 2>/dev/null
else
  Test_Button_R2 2>/dev/null
fi

if [ "$?" -eq "10" ] && [[ -z "$@" ]]; then
  speak "The current performance governor is $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)"
  if [[ $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null) == "userspace" ]]; then
    speak "CPU speed is currently $(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)" &
  fi
else
  if [[ -f /tmp/battery.percent ]]; then
    BAT_FILE="/tmp/battery.percent"
  else
    BAT_FILE="/sys/class/power_supply/battery/capacity"
  fi
  bat_val=$(cat "$BAT_FILE" 2>/dev/null | tr -dc '0-9')
  [ -z "$bat_val" ] && bat_val="unknown"

  if [[ ! -z "$@" ]]; then
    speak "${@} $bat_val percent"
  else
    speak "Your battery level is at $bat_val percent"
  fi

  Test_Button_R2 2>/dev/null
  if [ "$?" -eq "10" ]; then
    speak "The current performance governor is $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)"
    if [[ $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null) == "userspace" ]]; then
      speak "CPU speed is currently $(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)" &
    fi
  fi
fi
