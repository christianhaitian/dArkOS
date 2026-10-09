#!/bin/bash
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

. /usr/local/bin/buttonmon.sh 2>/dev/null

# Detect language from EmulationStation configuration or system
get_language() {
  local lang
  if [ -f "/home/ark/.emulationstation/es_settings.cfg" ]; then
    lang=$(grep '<string name="Language"' /home/ark/.emulationstation/es_settings.cfg 2>/dev/null | sed -n 's/.*value="\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')
  fi
  if [ -z "$lang" ] && [ -f "/home/ark/.config/.LANGUAGE" ]; then
    lang=$(cat /home/ark/.config/.LANGUAGE 2>/dev/null | tr -dc 'a-zA-Z_' | tr '[:upper:]' '[:lower:]')
  fi
  if [ -z "$lang" ]; then
    lang="${LANG:0:2}"
  fi
  [ -z "$lang" ] && lang="en"
  echo "${lang:0:2}"
}

LANG_CODE=$(get_language)

# Select voice based on MBROLA config or language
if [ -e "/home/ark/.config/.MBROLA_VOICE_FEMALE" ]; then
  mb_voice="1"
elif [ -e "/home/ark/.config/.MBROLA_VOICE_MALE3" ]; then
  mb_voice="3"
else
  mb_voice="2"
fi

speak_text() {
  local voice_param="$1"
  local text="$2"

  if [ "$(id -u)" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
    runuser -u ark -- espeak-ng $voice_param -s130 "$text" 2>/dev/null || espeak-ng -s130 "$text" 2>/dev/null
  else
    espeak-ng $voice_param -s130 "$text" 2>/dev/null || espeak-ng -s130 "$text" 2>/dev/null
  fi
}

speak_i18n() {
  local type="$1"   # "battery", "governor", "cpu_speed", "critical_suspend", "custom"
  local val="$2"

  local voice_arg=""
  local msg=""

  case "$LANG_CODE" in
    pl)
      voice_arg="-vpl"
      case "$type" in
        battery)          msg="Poziom baterii wynosi $val procent" ;;
        governor)         msg="Aktualny profil zasilania to $val" ;;
        cpu_speed)        msg="Taktowanie procesora wynosi $val" ;;
        critical_suspend) msg="Krytyczny poziom baterii. Nastepuje uspienie konsoli." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    es)
      voice_arg="-ves"
      case "$type" in
        battery)          msg="El nivel de batería es del $val por ciento" ;;
        governor)         msg="El perfil de rendimiento actual es $val" ;;
        cpu_speed)        msg="La velocidad de la CPU es $val" ;;
        critical_suspend) msg="Nivel crítico de batería. Suspendiendo la consola." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    fr)
      voice_arg="-vfr"
      case "$type" in
        battery)          msg="Le niveau de batterie est à $val pour cent" ;;
        governor)         msg="Le profil de performance actuel est $val" ;;
        cpu_speed)        msg="La vitesse du processeur est de $val" ;;
        critical_suspend) msg="Niveau de batterie critique. Mise en veille de la console." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    de)
      voice_arg="-vde"
      case "$type" in
        battery)          msg="Der Akkustand beträgt $val Prozent" ;;
        governor)         msg="Das aktuelle Leistungsprofil ist $val" ;;
        cpu_speed)        msg="Die CPU Geschwindigkeit beträgt $val" ;;
        critical_suspend) msg="Kritischer Batteriestand. Konsole wird in den Ruhezustand versetzt." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    it)
      voice_arg="-vit"
      case "$type" in
        battery)          msg="Il livello della batteria è al $val per cento" ;;
        governor)         msg="Il profilo delle prestazioni è $val" ;;
        cpu_speed)        msg="La velocità della CPU è $val" ;;
        critical_suspend) msg="Livello di batteria critico. Sospensione della console." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    pt)
      voice_arg="-vpt"
      case "$type" in
        battery)          msg="O nível da bateria está em $val por cento" ;;
        governor)         msg="O perfil de desempenho atual é $val" ;;
        cpu_speed)        msg="A velocidade da CPU é $val" ;;
        critical_suspend) msg="Nível crítico de bateria. Suspendendo o console." ;;
        custom)           msg="$val" ;;
      esac
      ;;
    *)
      voice_arg="-vmb-us${mb_voice}"
      case "$type" in
        battery)          msg="Your battery level is at $val percent" ;;
        governor)         msg="The current performance governor is $val" ;;
        cpu_speed)        msg="CPU speed is currently $val" ;;
        critical_suspend) msg="Critical battery level. Suspending console now." ;;
        custom)           msg="$val" ;;
      esac
      ;;
  esac

  speak_text "$voice_arg" "$msg"
}

# Check special argument
if [[ "$1" == "critical_suspend" ]]; then
  speak_i18n "critical_suspend" ""
  exit 0
fi

# Check trigger buttons
if [ -f "/boot/rk3326-rg351v-linux.dtb" ] || [ -f "/boot/rk3326-gameforce-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ]; then
  Test_Button_R1 2>/dev/null
else
  Test_Button_R2 2>/dev/null
fi

if [ "$?" -eq "10" ] && [[ -z "$@" ]]; then
  gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)
  speak_i18n "governor" "$gov"
  if [[ "$gov" == "userspace" ]]; then
    freq_str=$(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)
    speak_i18n "cpu_speed" "$freq_str" &
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
    speak_i18n "custom" "${@} $bat_val"
  else
    speak_i18n "battery" "$bat_val"
  fi

  Test_Button_R2 2>/dev/null
  if [ "$?" -eq "10" ]; then
    gov=$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null)
    speak_i18n "governor" "$gov"
    if [[ "$gov" == "userspace" ]]; then
      freq_str=$(awk 'length==6{printf("%.0f MHz\n", $0/10^3); next} length==7{printf("%.1f GHz\n", $0/10^6)}' /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq 2>/dev/null)
      speak_i18n "cpu_speed" "$freq_str" &
    fi
  fi
fi
