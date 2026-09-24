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
