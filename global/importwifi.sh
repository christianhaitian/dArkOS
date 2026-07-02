#!/bin/bash


if [[ -f $(find /opt/system/Tools -maxdepth 1 -iname wifikeyfile.txt) ]]; then

	keyfile=`find /opt/system/Tools -maxdepth 1 -iname wifikeyfile.txt`
	keyfile_base=`basename $keyfile`
	sudo chmod 666 /dev/tty1
	export TERM=linux
	export XDG_RUNTIME_DIR=/run/user/$UID/
	printf "\033c" > /dev/tty1
	printf "\e[?25l" > /dev/tty1
	dialog --clear

	height="15"
	width="55"

	if [ -f "/boot/rk3326-rg351v-linux.dtb" ]; then
	  sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
	  height="20"
	  width="60"
	elif [[ -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
	  sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
	  height="20"
	  width="60"
	elif [[ -e "/dev/input/by-path/platform-singleadc-joypad-event-joystick" ]]; then
	  sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
	  height="20"
	  width="60"
	else
	  sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
	  height="20"
	  width="60"
	fi

	if [[ ! -z $(cat /etc/modprobe.d/blacklist.conf | grep 8821cs | tr -d '\0') ]]; then
	  dialog --infobox "Your wifi connection is off.  Please enable it in options>advanced then reboot so importing of your wifi credentials can be completed." 5 $width > /dev/tty1
	  sleep 10
	  exit 0
	fi

	if [[ -z $(ifconfig | grep wlan0 | tr -d '\0') ]]; then
	  dialog --infobox "Waiting for wifi adapter to be enabled.  Please wait..." 5 $width > /dev/tty1
	  printf "Waiting for wifi adapter to be enabled.  Please wait..."
	  sleep 10
	  if [[ -z $(ifconfig | grep wlan0 | tr -d '\0') ]]; then
	    dialog --infobox "There isn't a compatible wifi adapter connected.  Please plug in a compatible wifi adapter then reboot so importing of your wifi credentials can be completed." 5 $width > /dev/tty1
	    sleep 10
	    exit 0
	  fi
	fi

	dialog --infobox "Starting Wifi importer.  Please wait..." 5 $width > /dev/tty1
	#printf "Starting Wifi importer.  Please wait..." > /dev/tty1
	sudo systemctl stop networkwatchdaemon
	sudo systemctl restart NetworkManager

	dos2unix "$keyfile"
	mapfile wificreds < "$keyfile"
	ssid=$(echo ${wificreds[0]} | grep -oP '(?<=").*?(?=")')
	pass=$(echo ${wificreds[1]} | grep -oP '(?<=").*?(?=")')

	if [ ! -z "$ssid" ] && [ ! -z "$pass" ]; then
	  dialog --infobox "\nConnecting to $ssid ..." 5 $width > /dev/tty1

	  # try to connect
	  sudo nmcli con delete "$ssid" > /dev/null
	  #workaround for wpa2/wpa3 connectivity
	  sudo nmcli c add con-name "$ssid" type wifi ssid "$ssid" ifname wlan0 > /dev/null
	  sudo nmcli c modify "$ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$pass" > /dev/null
	  output=`sudo nmcli con up "$ssid"`

	  success=`echo "$output" | grep successfully`

	  if [ -z "$success" ]; then
		output="Activation failed: File has been renamed to ${keyfile_base}.nogood in the tools folder.  Please review it, correct it, rename it back to wifikeyfile.txt and try again."
		sudo nmcli con delete "$ssid" > /dev/null
		cp -f "$keyfile" "$keyfile".nogood
		rm -f "$keyfile"
	  else
		rm -f "$keyfile"
		output="Device successfully activated and connected to $ssid.\n\n${keyfile_base} has been deleted for security purposes."
	  fi

	  dialog --infobox "\n$output" 8 $width > /dev/tty1
	  sleep 10
	else
	  cp -f "$keyfile" "$keyfile".nogood
	  rm -f "$keyfile"
	  dialog --infobox "The contents of the ${keyfile_base} are invalid.  It can not be imported.  File has been renamed to ${keyfile}.nogood in the tools folder." $height $width 2>&1 > /dev/tty1 
	  sleep 10
	fi
	sudo systemctl stop NetworkManager
	sudo systemctl start networkwatchdaemon
	dialog --clear
	printf "\033c" > /dev/tty1
	exit 0
fi

exit 0
