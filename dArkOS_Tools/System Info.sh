#!/bin/bash

# basic system information for DarkOS
# by daedalus-code

################################################################################

# users, host, uptime, load, ip, cpu model
USERS=$(who | wc -l)
HOST=$(hostname)
UPTIME=$(uptime -p)
LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
IP=$(hostname -I | awk '{print $1}')
CPU_MODEL=$(awk -F: '/model name|Hardware/ {print $2; exit}' /proc/cpuinfo | xargs)

# load, srcds, screen pid
SYSTEM_LOAD="$(awk '{ print $1,$2,$3 }' /proc/loadavg)"
# get number of CPU cores
CPU_CORES=$(nproc)
# read individual load numbers into variables
read LOAD1 LOAD2 LOAD3 <<<"$SYSTEM_LOAD"
# calculate average load
AVG_LOAD=$(awk -v l1="$LOAD1" -v l2="$LOAD2" -v l3="$LOAD3" 'BEGIN { print (l1+l2+l3)/3 }')
# convert to percentage
LOAD_PCT=$(awk -v avg="$AVG_LOAD" -v cores="$CPU_CORES" 'BEGIN { printf "%.2f", (avg/cores)*100 }')

################################################################################

# cpu raw
CPU_TEMP_RAW=$(</sys/class/thermal/thermal_zone1/temp)
# cpu temp
CPU_TEMP=$((CPU_TEMP_RAW / 1000))
# cpu type
CPU_TYPE=$(</sys/class/thermal/thermal_zone1/type)

################################################################################

# battery raw
BATTERY_TEMP_RAW=$(</sys/class/thermal/thermal_zone0/temp)
# battery temp
BATTERY_TEMP=$((BATTERY_TEMP_RAW / 1000))
# battery type
BATTERY_TYPE=$(</sys/class/thermal/thermal_zone0/type)
# battery capacity
BATTERY_CAPACITY="$(cat /sys/class/power_supply/battery/capacity)"
# battery status
BATTERY_STATUS="$(cat /sys/class/power_supply/battery/status)"
# battery voltage
BATTERY_VOLTAGE="$(awk '{printf "%.2f", $1/1000000}' /sys/class/power_supply/battery/voltage_now)"
# battery current
BATTERY_CURRENT="$(awk '{printf "%.2f", $1/1000000}' /sys/class/power_supply/battery/current_now)"

################################################################################

# read RAM
MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

# read swap
SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))

# RAM used
MEM_USED=$((MEM_TOTAL - MEM_AVAILABLE))

# convert to MB
MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
MEM_USED_MB=$((MEM_USED / 1024))
SWAP_TOTAL_MB=$((SWAP_TOTAL / 1024))
SWAP_USED_MB=$((SWAP_USED / 1024))

# total memory
TOTAL_MEM_MB=$((MEM_TOTAL_MB + SWAP_TOTAL_MB))
# total memory used
TOTAL_USED_MEM_MB=$((MEM_USED_MB + SWAP_USED_MB))

# percentages
MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
SWAP_PCT=$((SWAP_TOTAL > 0 ? SWAP_USED * 100 / SWAP_TOTAL : 0))
TOTAL_PCT=$((TOTAL_USED_MEM_MB * 100 / TOTAL_MEM_MB))

################################################################################

# get primary network interface (skip loopback)
NET_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)

# get RX and TX bytes in MB
RX_BYTES=$(cat /sys/class/net/$NET_IFACE/statistics/rx_bytes)
TX_BYTES=$(cat /sys/class/net/$NET_IFACE/statistics/tx_bytes)
RX_MB=$(awk -v b="$RX_BYTES" 'BEGIN {printf "%.2f", b/1024/1024}')
TX_MB=$(awk -v b="$TX_BYTES" 'BEGIN {printf "%.2f", b/1024/1024}')

# network speed
U=$(awk '{print int($1)}' /proc/uptime)
read RX TX <<<$(awk -v i="$NET_IFACE" '$1 ~ i ":" {gsub(":","",$2); print $2, $10}' /proc/net/dev)

################################################################################

# system space /
SPACE_NAME=$(df -h / | awk 'NR==2 {print $1" - "$NF}')
SPACE_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
SPACE_USED=$(df -h / | awk 'NR==2 {print $3}')
SPACE_FREE=$(df -h / | awk 'NR==2 {print $4}')
SPACE_PCT=$(df -h / | awk 'NR==2 {print $5}')
# roms space /roms
ROMS_SPACE_NAME=$(df -h /roms | awk 'NR==2 {print $1" - "$NF}')
ROMS_SPACE_TOTAL=$(df -h /roms | awk 'NR==2 {print $2}')
ROMS_SPACE_USED=$(df -h /roms | awk 'NR==2 {print $3}')
ROMS_SPACE_FREE=$(df -h /roms | awk 'NR==2 {print $4}')
ROMS_SPACE_PCT=$(df -h /roms | awk 'NR==2 {print $5}')
# roms2 space /roms2
ROMS2_SPACE_NAME=$(df -h /roms2 | awk 'NR==2 {print $1" - "$NF}')
ROMS2_SPACE_TOTAL=$(df -h /roms2 | awk 'NR==2 {print $2}')
ROMS2_SPACE_USED=$(df -h /roms2 | awk 'NR==2 {print $3}')
ROMS2_SPACE_FREE=$(df -h /roms2 | awk 'NR==2 {print $4}')
ROMS2_SPACE_PCT=$(df -h /roms2 | awk 'NR==2 {print $5}')

################################################################################

# dialog window
msgbox "$(date | xargs)

Host....: $HOST
Users...: $USERS ($(users))
Uptime..: $UPTIME
Load....: $LOAD

Network.: $NET_IFACE
Address.: $IP
Down....: ${RX_MB}MB $((RX / 1024 / U)) KB/s
Up......: ${TX_MB}MB $((TX / 1024 / U)) KB/s

CPU.....: $CPU_TYPE
Model...: $CPU_MODEL
Temp....: ${CPU_TEMP}°C

Battery.: $BATTERY_TYPE
Charge..: ${BATTERY_CAPACITY}% ($BATTERY_STATUS)
Temp....: ${BATTERY_TEMP}°C
Voltage.: $BATTERY_VOLTAGE μV
Current.: $BATTERY_CURRENT μA

Memory..: Used: ${MEM_USED_MB}MB Total: ${MEM_TOTAL_MB}MB (${MEM_PCT}%)
Swap....: Used: ${SWAP_USED_MB}MB Total: ${SWAP_TOTAL_MB}MB (${SWAP_PCT}%)

$SPACE_NAME
├─Disk..: $SPACE_TOTAL
├─Used..: $SPACE_PCT - $SPACE_USED
└─Free..: $SPACE_FREE

$ROMS_SPACE_NAME
├─Disk..: $ROMS_SPACE_TOTAL
├─Used..: $ROMS_SPACE_PCT - $ROMS_SPACE_USED
└─Free..: $ROMS_SPACE_FREE

$ROMS2_SPACE_NAME
├─Disk..: $ROMS2_SPACE_TOTAL
├─Used..: $ROMS2_SPACE_PCT - $ROMS2_SPACE_USED
└─Free..: $ROMS2_SPACE_FREE"

# END
