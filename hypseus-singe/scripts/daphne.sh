#!/bin/bash

if  [[ $1 == "standalone" ]]; then

  directory=$(dirname "$2" | cut -d "/" -f2)

  unlink /opt/hypseus-singe/roms
  if [ $? != 0 ]; then
    sudo rm -rf /opt/hypseus-singe/roms
  fi
  ln -sfv /$directory/daphne/roms/ /opt/hypseus-singe/roms

  dir="$2"
  basedir=$(basename -- $dir)
  basefilename=${basedir%.*}

  if [ -f "$dir/$basefilename.commands" ]; then
     extraparams=$(<"$dir/$basefilename.commands")
  fi

  echo "VAR=hypseus-singe" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service

  cd /opt/hypseus-singe

  if [[ $(cat /sys/class/graphics/fb0/modes | grep -o -P '(?<=:).*(?=p-)') == "720x720" ]]; then
    RES="-x 720 -y 600"
  fi

  case "$basefilename" in
    ace)
	FASTBOOT="-fastboot"
	BANKS="-bank 1 00000001 -bank 0 00000010"
	;;
    aceeuro|ace91)
	;;
    astron)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    badlands)
	BANKS="-blank_searches -blank_skips -min_seek_delay 600"
	;;
    badlandp)
	BANKS="-spritelite -preset 1"
	;;
    bega)
	;;
    blazer)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    cliff|cliffalt|cliffalt2)
	FASTBOOT="-fastboot"
	BANKS="-bank 1 00000000 -bank 0 00000000 -cheat"
	;;
    cliff_ox)
	FASTBOOT="-fastboot"
	;;
    cobra)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    cobraab)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    cobraconv)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    cobram3)
	KEYINPUT="-keymapfile flightkey.ini"
	FASTBOOT="-nocrc"
	;;
    dle21)
	FASTBOOT="-fastboot"

	if [ "$PROTOTYPE" ]; then
		BANKS="-bank 1 10100111 -bank 0 11011000"
	else
		BANKS="-bank 1 00110111 -bank 0 11011000"
	fi
	;;
    esh|eshalt|eshalt2|eshfix7|eshfix7alt|eshfix7alt2)
	;;
    galaxy|galaxyp)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    gpworld)
	;;
    gtg)
	FASTBOOT="-fastboot"
	;;
    interstellar)
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    mach3)
	BANKS="-bank 0 01000001"
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    lair)
	FASTBOOT="-fastboot"
	BANKS="-bank 1 00110111 -bank 0 10011001"
	;;
    laireuro|lair_ita)
	;;
    lair2)
	;;
    roadblaster)
	;;
    sae)
	FASTBOOT="-fastboot"
	BANKS="-bank 1 01100111 -bank 0 10011000"
	;;
    sdq|sdqshort|sdqshortalt)
	BANKS="-bank 1 00000000 -bank 0 00000000"
	;;
    tq|tq_alt|tq_swear)
	BANKS=" -bank 0 00010000"
	;;
    uvt)
	BANKS="-bank 0 01000000"
	KEYINPUT="-keymapfile flightkey.ini"
	;;
    *) echo -e "\nInvalid game selected\n"
       exit 1
  esac

  #./hypseus-singe "$basefilename" vldp -gamepad ${RES} -framefile "$dir/$basefilename.txt" -fullscreen -useoverlaysb 2 $extraparams
  ./hypseus-singe "$basefilename" vldp $FASTBOOT -gamepad -texturestream ${RES} $KEINPUT $BANKS -framefile "$dir/$basefilename.txt" -fullscreen $extraparams

  rm *.csv

  sudo systemctl stop killer_daemon.service
else
  /usr/local/bin/"$1" -L /home/ark/.config/"$1"/cores/"$2"_libretro.so "$3"
fi
