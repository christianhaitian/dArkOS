#!/bin/bash

##################################################################
# Apple II script by Slayer366.  Much of this script takes from  #
# the great work from other launch scripts by Christian Haitian  #
# and EnsignRutherford.  It has then been revised for Apple II.  #
##################################################################

sudo chmod 666 /dev/tty0
sudo chmod 666 /dev/tty1
sudo chmod 666 /dev/uinput

EMULATOR=$1
if [ "$#" -gt 2 ]; then
  GAME="$3"
else
  GAME="$2"
fi

if [[ $EMULATOR == "linapple" ]]; then

  directory=$(dirname "$GAME" | cut -d "/" -f2)
  GPTOKEYB="/opt/inttools/gptokeyb -1"
  export SDL_GAMECONTROLLERCONFIG_FILE="/opt/linapple/gamecontrollerdb.txt"
  #export SDL_GAMECONTROLLERCONFIG="$(cat /opt/linapple/gamecontrollerdb.txt)"

  # The next 2 variables are for use with custom game controls if the user creates some
  gamecontrols=$(echo "$(ls "$GAME" | cut -d "/" -f4 | cut -d "." -f1)")
  custom_gamecontrols_nocase=$(find /$directory/apple2/controls -maxdepth 1 -iname "${gamecontrols}".gptk -print -quit 2>/dev/null)

  # The next 2 variables are for use with a custom linapple config if the user creates some
  linappleconfig=$(echo "$(ls "$GAME" | cut -d "/" -f4 | cut -d "." -f1)")
  custom_linappleconfig_nocase=$(find "/$directory/apple2/conf" -maxdepth 1 -iname "${linappleconfig}".conf)

  # This gaurd is specifically for the Chi to change the exit hotkey to be 1 and Start as other emulators and tools are for that unit
  if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]] || [[ -e "/dev/input/by-path/platform-gameforce-gamepad-event-joystick" ]]; then
    export HOTKEY="l3"
  fi

  # Here we can load custom game controls instead of the default controls.
  # Users can create their own mappings for each game.  
  # Just create a controls subfolder within the roms/apple2 (roms2/apple2 for 2 sd card setups) 
  # folder and create a text file named exactly similar to game name but with a .gptk extension.
  # See https://raw.githubusercontent.com/christianhaitian/arkos/main/mvem%20pics/mvem.gptk
  # for an example of how to setup the structure of this file.
  # Unused gamepad keys should be commented out with \" like the start key is in the example .gptk
  # file linked in the previous sentence.
      if [ -f "$custom_gamecontrols_nocase" ]; then
        $GPTOKEYB "linapple" -c "$custom_gamecontrols_nocase" &
      else
        #echo "Loading default controls /opt/linapple/controls/linapple.gptk" >> /dev/tty1
        $GPTOKEYB "linapple" -c "/opt/linapple/controls/linapple.gptk" &
      fi

	if [ ".$(echo "$GAME"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".SH" ]; then
	"$GAME"
	elif [ ".$(echo "$GAME"| cut -d. -f2)" == ".apple2" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".APPLE2" ]; then
	  DISK1=""; DISK2=""; HDD1=""; HDD2=""; CONF=""; PARAMS=""; APPLE2_BASE_DIR="/$directory/apple2/"
	  dos2unix "${GAME}"
	  while IFS== read -r key value; do
	    if [ "$key" == "DISK1" ]; then DISK1+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "DISK2" ]; then DISK2+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "HDD1" ]; then HDD1+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "HDD2" ]; then HDD2+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "CONF" ]; then CONF+=" ${APPLE2_BASE_DIR}conf/${value}"
	    fi
	  done < "${GAME}"
	  if [ "$DISK1" ]; then PARAMS+=" --d1 ${DISK1:1}"; fi
	  if [ "$DISK2" ]; then PARAMS+=" --d2 ${DISK2:1}"; fi
	  if [ "$HDD1" ]; then PARAMS+=" --hd1 ${HDD1:1}"; fi
	  if [ "$HDD2" ]; then PARAMS+=" --hd2 ${HDD2:1}"; fi
	  if [ "$CONF" ]; then PARAMS+=" --conf ${CONF:1}"; fi
      if [ -z "$CONF" ]; then PARAMS+=" --conf /opt/linapple/conf/linapple.conf "; fi
	  /opt/linapple/linapple ${PARAMS:1} --autoboot
	else
	   if [ -f "$custom_linappleconfig_nocase" ]; then
	     #echo "Loading custom linapple config from $custom_linappleconfig_nocase" >> /dev/tty1
	     /opt/linapple/linapple --conf "$custom_linappleconfig_nocase" --d1 "$GAME" --autoboot
	   else
	     #echo "Loading default config /opt/linapple/conf/normaljoy.conf" >> /dev/tty1
	     /opt/linapple/linapple --conf "/opt/linapple/conf/normaljoy.conf" --d1 "$GAME" --autoboot
	   fi
	fi
           unset SDL_GAMECONTROLLERCONFIG_FILE
           unset SDL_GAMECONTROLLERCONFIG
           if [[ ! -z $(pidof gptokeyb) ]]; then
             sudo kill -9 $(pidof gptokeyb)
           fi
           printf "\033c" >> /dev/tty0
           printf "\033c" >> /dev/tty1
           sudo systemctl restart ogage &
elif [[ $EMULATOR == "applewin" ]]; then
        sudo chown ark:ark /home/ark/.applewin/applewin.conf
	sed -i 's/Last Harddisk Image 1=.*/Last Harddisk Image 1=/' ~/.applewin/applewin.conf
        if [[ "$2" == *"no-"* ]]; then
          sudo sed -i 's/Video Style\=.*/Video Style\=0/g' /home/ark/.applewin/applewin.conf
        else
          sudo sed -i 's/Video Style\=.*/Video Style\=1/g' /home/ark/.applewin/applewin.conf
        fi
        sudo chown ark:ark /home/ark/.applewin/applewin.conf
        directory=$(dirname "$GAME" | cut -d "/" -f2)
        GPTOKEYB="/opt/inttools/gptokeyb -1"
        export SDL_GAMECONTROLLERCONFIG_FILE="/opt/linapple/gamecontrollerdb.txt"
        export SDL_GAMECONTROLLERCONFIG="$(cat /opt/linapple/gamecontrollerdb.txt)"
        if [[ $(cat /home/ark/.config/.DEVICE) == "MINILOONG" ]]; then
          export HOTKEY="guide"
        fi
        # The next 2 variables are for use with custom game controls if the user creates some
        gamecontrols=$(echo "$(ls "$GAME" | cut -d "/" -f4 | cut -d "." -f1)")
        custom_gamecontrols_nocase=$(find "/$directory/apple2/controls" -maxdepth 1 -iname "${gamecontrols}".gptk)

	  # This gaurd is specifically for the Chi to change the exit hotkey to be 1 and Start as other emulators and tools are for that unit
	  if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]] || [[ -e "/dev/input/by-path/platform-gameforce-gamepad-event-joystick" ]]; then
		export HOTKEY="l3"
	  fi

	# This section will clear out all previously entered disk images because applewin will default to
	# booting a hard disk image if one was loaded previously and will not boot to any floppy disks after.
	sed -i 's/Last Harddisk Image 1=.*/Last Harddisk Image 1=/' ~/.applewin/applewin.conf
	sed -i 's/Last Harddisk Image 2=.*/Last Harddisk Image 2=/' ~/.applewin/applewin.conf
	sed -i 's/Last Disk Image 1=.*/Last Disk Image 1=/' ~/.applewin/applewin.conf
	sed -i 's/Last Disk Image 2=.*/Last Disk Image 2=/' ~/.applewin/applewin.conf

      # Here we can load custom game controls instead of the default controls.
      # Users can create their own mappings for each game.  
      # Just create a controls subfolder within the roms/apple2 (roms2/apple2 for 2 sd card setups) 
      # folder and create a text file named exactly similar to game name but with a .gptk extension.
      # See https://raw.githubusercontent.com/christianhaitian/arkos/main/mvem%20pics/mvem.gptk
      # for an example of how to setup the structure of this file.
      # Unused gamepad keys should be commented out with \" like the start key is in the example .gptk
      # file linked in the previous sentence.
      if [ -f "$custom_gamecontrols_nocase" ]; then
        #echo "Loading custom user controls from $custom_gamecontrols_nocase" >> /dev/tty1
        $GPTOKEYB "sa2" -c "$custom_gamecontrols_nocase" &
      else
        #echo "Loading default controls /opt/linapple/controls/linapple.gptk" >> /dev/tty1
        $GPTOKEYB "sa2" -c "/opt/linapple/controls/linapple.gptk" &
      fi

	if [ ".$(echo "$GAME"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".SH" ]; then
	  "$GAME"
	elif [ ".$(echo "$GAME"| cut -d. -f2)" == ".apple2" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".APPLE2" ]; then
	  DISK1=""; DISK2=""; HDD=""; PARAMS=""; APPLE2_BASE_DIR="/$directory/apple2/"
	  dos2unix "${GAME}"
	  while IFS== read -r key value; do
	    if [ "$key" == "DISK1" ]; then DISK1+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "DISK2" ]; then DISK2+=" ${APPLE2_BASE_DIR}${value}"
	    elif [ "$key" == "HDD" ]; then HDD+=" ${APPLE2_BASE_DIR}${value}"
	    fi
	  done < "${GAME}"
	  if [ "$DISK1" ]; then PARAMS+=" -1 ${DISK1:1}"; fi
	  if [ "$DISK2" ]; then PARAMS+=" -2 ${DISK2:1}"; fi
	  if [ "$HDD" ]; then PARAMS+=" --h1 ${HDD:1}"; fi
	  LD_LIBRARY_PATH=/opt/applewin/libs /opt/applewin/applewin/sa2 --game-mapping-file /opt/linapple/gamecontrollerdb.txt --fixed-speed --no-imgui ${PARAMS:1}
	elif [ ".$(echo "$GAME"| cut -d. -f2)" == ".hdv" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".HDV" ]; then
	  LD_LIBRARY_PATH=/opt/applewin/libs /opt/applewin/applewin/sa2 --game-mapping-file /opt/linapple/gamecontrollerdb.txt --fixed-speed --no-imgui --h1 "$GAME"
          sed -i 's/Last Harddisk Image 1=.*/Last Harddisk Image 1=/' ~/.applewin/applewin.conf
	else
	  LD_LIBRARY_PATH=/opt/applewin/libs /opt/applewin/applewin/sa2 --game-mapping-file /opt/linapple/gamecontrollerdb.txt --fixed-speed --no-imgui -1 "$GAME"
	fi
        unset SDL_GAMECONTROLLERCONFIG_FILE
        unset SDL_GAMECONTROLLERCONFIG
        if [[ ! -z $(pidof gptokeyb) ]]; then
          sudo kill -9 $(pidof gptokeyb)
        fi
        printf "\033c" >> /dev/tty0
        printf "\033c" >> /dev/tty1
        sudo systemctl restart oga_events &
elif [[ $EMULATOR == "shamusworld" ]]; then
        directory=$(dirname "$GAME" | cut -d "/" -f2)
        GPTOKEYB="/opt/shamusworld/gptokeyb -1"
        export SDL_GAMECONTROLLERCONFIG_FILE="/opt/shamusworld/gamecontrollerdb.txt"
        export SDL_GAMECONTROLLERCONFIG="$(cat /opt/shamusworld/gamecontrollerdb.txt)"

        # The next 2 variables are for use with custom game controls if the user creates some
        gamecontrols=$(echo "$(ls "$GAME" | cut -d "/" -f4 | cut -d "." -f1)")
        custom_gamecontrols_nocase=$(find "/$directory/apple2/controls" -maxdepth 1 -iname "${gamecontrols}".gptk)

      # Here we can load custom game controls instead of the default controls.
      # Users can create their own mappings for each game.  
      # Just create a controls subfolder within the roms/apple2 (roms2/apple2 for 2 sd card setups) 
      # folder and create a text file named exactly similar to game name but with a .gptk extension.
      # See https://raw.githubusercontent.com/christianhaitian/arkos/main/mvem%20pics/mvem.gptk
      # for an example of how to setup the structure of this file.
      # Unused gamepad keys should be commented out with \" like the start key is in the example .gptk
      # file linked in the previous sentence.
      if [ -f "$custom_gamecontrols_nocase" ]; then
        #echo "Loading custom user controls from $custom_gamecontrols_nocase" >> /dev/tty1
        $GPTOKEYB "apple2" -c "$custom_gamecontrols_nocase" &
      else
        #echo "Loading default controls /opt/shamusworld/controls/apple2.gptk" >> /dev/tty1
        $GPTOKEYB "apple2" -c "/opt/shamusworld/controls/apple2.gptk" &
      fi

        if [ ".$(echo "$2"| cut -d. -f2)" == ".sh" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".SH" ]; then
        "$2"
        elif [ ".$(echo "$2"| cut -d. -f2)" == ".apple2" ] || [ ".$(echo "$2"| cut -d. -f2)" == ".APPLE2" ]; then
          DISK1=""; PARAMS=""; APPLE2_BASE_DIR="/$directory/apple2/"
          dos2unix "${2}"
          while IFS== read -r key value; do
            if [ "$key" == "DISK1" ]; then DISK1+=" ${APPLE2_BASE_DIR}${value}"
            fi
          done < "${2}"
          if [ "$DISK1" ]; then PARAMS+=" ${DISK1:1}"; fi
          cd /opt/shamusworld
          /opt/shamusworld/apple2 ${PARAMS:1}
        else
         cd /opt/shamusworld
         /opt/shamusworld/apple2 "$2"
        fi
           unset SDL_GAMECONTROLLERCONFIG_FILE
           unset SDL_GAMECONTROLLERCONFIG
           if [[ ! -z $(pidof gptokeyb) ]]; then
             sudo kill -9 $(pidof gptokeyb)
           fi
           printf "\033c" >> /dev/tty0
           printf "\033c" >> /dev/tty1
           sudo systemctl restart oga_events &
elif [[ $EMULATOR == "retroarch" ]] && [[ $2 == "mess" ]]; then
  # Check if this is a hard drive image.  If so, stop and inform the user to change to the applewin emulator for this game
  if [ ".$(echo "$GAME"| cut -d. -f2)" == ".hdv" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".HDV" ]; then
    msgbox "This hard drive image will not work with the $EMULATOR mess emulator.  Please change the emulator for this game to applewin then try it again."
    exit 0
  fi
  directory=$(dirname "$GAME" | cut -d "/" -f2)
  /usr/local/bin/"$EMULATOR" -v -L /home/ark/.config/"$EMULATOR"/cores/"$2"_libretro.so "apple2e -rp /$directory/bios -gameio joy -flop1 ""$3"
else
  # Check if this is a hard drive image.  If so, stop and inform the user to change to the applewin emulator for this game
  if [ ".$(echo "$GAME"| cut -d. -f2)" == ".hdv" ] || [ ".$(echo "$GAME"| cut -d. -f2)" == ".HDV" ]; then
    msgbox "This hard drive image will not work with the $EMULATOR emulator.  Please change the emulator for this game to applewin then try it again."
    exit 0
  fi
  LD_LIBRARY_PATH=/opt/applewin/libs/ /usr/local/bin/"$EMULATOR" -L /home/ark/.config/"$EMULATOR"/cores/"$2"_libretro.so "$3"
fi

