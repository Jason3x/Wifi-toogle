#!/bin/bash

#-----------------------------------
# Script to enable/disable WiFi on the R36S console under ArkOS AeUX
#-----------------------------------


CURR_TTY="/dev/tty1"

sudo chmod 666 $CURR_TTY
reset

# Hide cursor
printf "\e[?25l" > $CURR_TTY
dialog --clear

export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
else
    sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz
fi

pgrep -f gptokeyb | sudo xargs kill -9
pgrep -f osk.py | sudo xargs kill -9
printf "\033c" > $CURR_TTY
printf "Starting Wifi Manager. Please wait..." > $CURR_TTY

height="15"
width="55"

BACKTITLE="Wifi Manager by Jason"

WIFI_STATUS=$(nmcli radio wifi)
WIFI_CONFIG_FILE="/etc/wifi-status"

# Définir les chemins d'images
WIFI_IMAGE_PATH="/roms/wifi"
TARGET_IMAGE_PATH="/roms/themes/es-theme-nes-box/_inc/images/red"


# Vérifier et charger l'état du Wi-Fi depuis le fichier de configuration
if [[ -f "$WIFI_CONFIG_FILE" ]]; then
    SAVED_WIFI_STATUS=$(cat "$WIFI_CONFIG_FILE")
else
    SAVED_WIFI_STATUS="disabled"
fi

# Appliquer l'état sauvegardé au démarrage
if [[ "$SAVED_WIFI_STATUS" == "enabled" ]]; then
   sudo nmcli radio wifi on
else
   sudo nmcli radio wifi off
fi

# Mettre à jour l'état du Wi-Fi après modification
update_wifi_status() {
    WIFI_STATUS=$(nmcli radio wifi)
    if [[ "$WIFI_STATUS" == "enabled" ]]; then
        echo "enabled" | sudo tee "$WIFI_CONFIG_FILE" > /dev/null
        sudo cp "$WIFI_IMAGE_PATH/on1.png" "$TARGET_IMAGE_PATH/background_basic.png"
    sudo cp "$WIFI_IMAGE_PATH/on.png" "$TARGET_IMAGE_PATH/background.png"
    
    else
        echo "disabled" | sudo tee "$WIFI_CONFIG_FILE" > /dev/null
        sudo cp "$WIFI_IMAGE_PATH/off1.png" "$TARGET_IMAGE_PATH/background_basic.png"
    sudo cp "$WIFI_IMAGE_PATH/off.png" "$TARGET_IMAGE_PATH/background.png"
    fi
}

# Fonction pour activer le Wi-Fi
enable_wifi() {
    dialog --infobox "Enabling WiFi..." 3 40 > $CURR_TTY
    sleep 2
    sudo nmcli radio wifi on
    update_wifi_status
    dialog --msgbox "Wi-Fi successfully activated!" 6 40 > "$CURR_TTY"
    printf "\033c" > "$CURR_TTY"
    pgrep -f gptokeyb | sudo xargs kill -9
     
      # Redémarrer EmulationStation proprement
  sudo systemctl restart emulationstation &  # Lancer en arrière-plan pour éviter un blocage

  exit 0
}

# Fonction pour désactiver le Wi-Fi
disable_wifi() {
    dialog --infobox "Disabling WiFi..." 3 40 > $CURR_TTY
    sleep 2
    sudo nmcli radio wifi off
    update_wifi_status
    dialog --msgbox "Wi-Fi successfully disabled!" 6 40 > "$CURR_TTY"
    printf "\033c" > "$CURR_TTY"
    pgrep -f gptokeyb | sudo xargs kill -9
    exit 0
}

# Définition du titre selon l'état du Wi-Fi
if [[ "$WIFI_STATUS" == "enabled" ]]; then
    TITLE="Wi-Fi : Enable"
else
    TITLE="Wi-Fi : Disable"
fi


# Afficher le menu principal
MainMenu() {
  while true; do
    mainselection=(dialog \
        --backtitle "$BACKTITLE" \
        --title "Wi-Fi Manager - $TITLE" \
        --clear \
        --cancel-label "Exit" \
        --menu "Select an option:" 15 50 10)
    mainoptions=(
        1 "Enable Wi-Fi"
        2 "Disable le Wi-Fi"
    )
    mainchoices=$("${mainselection[@]}" "${mainoptions[@]}" 2>&1 > "$CURR_TTY")
    
    if [[ $? != 0 ]]; then
      exit 1
    fi

    case $mainchoices in
        1) enable_wifi ;;
        2) disable_wifi ;;
    esac
  done
}

# Contrôle du joystick (si applicable)
sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb > /dev/null && pgrep -f gptokeyb | sudo xargs kill -9
/opt/inttools/gptokeyb -1 "wifi-toogle.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
printf "\033c" > $CURR_TTY

dialog --clear

trap exit EXIT

# Lancer le menu principal
MainMenu
