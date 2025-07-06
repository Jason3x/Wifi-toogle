#!/bin/bash

# Script to enable/disable WiFi on the R36S console under ArkOS AeUX

#Add Wi-Fi icons

# --- Root Privilege Check ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi

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
printf "Starting Wifi Manager v2.0\nPlease wait..." > $CURR_TTY

sleep 2

height="15"
width="55"

BACKTITLE="Wi-Fi Management v2.0 - R36S - By Jason"

WIFI_STATUS=$(nmcli radio wifi)
WIFI_CONFIG_FILE="/etc/wifi-status"
THEMES_DIR="/roms/themes"
CURR_TTY="/dev/tty1"
PATCH_MARKER=".wifi_icon_patched"
MAINXML_MARKER=".wifi_icon_patched_mainxml"

WIFI_ICON_POS_X="0.16"
WIFI_ICON_POS_Y="0.025"
WIFI_ICON_SIZE="0.07"

UPDATER_PATH="/usr/local/bin/wifi_icon_state_updater.sh"
SERVICE_PATH="/etc/systemd/system/wifi-icon-updater.service"

UPDATE_INTERVAL=4  # seconds

# Check and load Wi-Fi state from the configuration file
if [[ -f "$WIFI_CONFIG_FILE" ]]; then
    SAVED_WIFI_STATUS=$(cat "$WIFI_CONFIG_FILE")
else
    SAVED_WIFI_STATUS="disabled"
fi

# Apply the saved state on startup
if [[ "$SAVED_WIFI_STATUS" == "enabled" ]]; then
   sudo nmcli radio wifi on
else
   sudo nmcli radio wifi off
fi

# Update Wi-Fi status after modification
update_wifi_status() {
    WIFI_STATUS=$(nmcli radio wifi)
    if [[ "$WIFI_STATUS" == "enabled" ]]; then
        echo "enabled" | sudo tee "$WIFI_CONFIG_FILE" > /dev/null
    else
        echo "disabled" | sudo tee "$WIFI_CONFIG_FILE" > /dev/null
    fi
}

# --- UI + Cleanup ---
exit_script() {
    printf "\033c" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb -1 Wifi-Toggle.sh" || true
    exit 0
}


restart_es_and_exit() {
    dialog --title "Restarting" --infobox "\nEmulationStation will now restart to apply changes..." 4 55 > "$CURR_TTY"
    sleep 2
    systemctl restart emulationstation &
    exit_script
}

create_updater_script() {
    cat > "$UPDATER_PATH" << 'EOF'
#!/bin/bash
THEMES_DIR="/roms/themes"
UPDATE_INTERVAL=5

prev_wifi_enabled=""

while true; do
    wifi_enabled=$(nmcli radio wifi)

    if [[ "$wifi_enabled" != "$prev_wifi_enabled" ]]; then
        for theme_path in "$THEMES_DIR"/*; do
            [ -d "$theme_path" ] || continue
            art_dir="$theme_path/_art"
            [ -d "$art_dir" ] || art_dir="$theme_path/art"
            [ -d "$art_dir" ] || continue

            icon_file="$art_dir/wifi.svg"
            on_bak="$art_dir/wifi_on.bak.svg"
            off_bak="$art_dir/wifi_off.bak.svg"

            if [[ "$wifi_enabled" == enabled* ]]; then
                [[ -f "$on_bak" ]] && cp "$on_bak" "$icon_file"
            else
                [[ -f "$off_bak" ]] && cp "$off_bak" "$icon_file"
            fi
        done

        systemctl restart emulationstation
        prev_wifi_enabled="$wifi_enabled"
    fi

    sleep "$UPDATE_INTERVAL"
done
EOF
    chmod +x "$UPDATER_PATH"
}

create_systemd_service() {
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Wi-Fi Icon State Updater
After=network.target

[Service]
ExecStart=$UPDATER_PATH
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable --now wifi-icon-updater.service
}

themes_already_patched() {
    local all_patched=true
    for theme_path in "$THEMES_DIR"/*; do
        [ -d "$theme_path" ] || continue
        theme_xml_file="$theme_path/theme.xml"
        [ ! -f "$theme_xml_file" ] && continue
        if [ ! -f "$theme_path/$PATCH_MARKER" ]; then
            all_patched=false
            break
        fi
    done

    # Vérifie aussi NES-box
    NESBOX_PATH="$THEMES_DIR/es-theme-nes-box"
    if [ -d "$NESBOX_PATH" ] && [ ! -f "$NESBOX_PATH/$MAINXML_MARKER" ]; then
        all_patched=false
    fi

    $all_patched
}

install_icons() {
    dialog --title "Installing Icons" --infobox "Installing Wi-Fi icons in themes.\nBackups will be created." 5 55 > "$CURR_TTY"
    sleep 2
    
        if themes_already_patched; then
        dialog --title "Already Patched" --msgbox "All themes are already patched.\nNo changes necessary." 6 50 > "$CURR_TTY"
        return
    fi

    local progress_text=""

    # Patch for all theme.xml themes
    for theme_path in "$THEMES_DIR"/*; do
        [ -d "$theme_path" ] || continue
        theme_xml_file="$theme_path/theme.xml"
        [ ! -f "$theme_xml_file" ] && continue
        [ -f "$theme_path/$PATCH_MARKER" ] && continue

        cp "$theme_xml_file" "${theme_xml_file}.bak"

        art_dir="$theme_path/_art"
        [ -d "$art_dir" ] || art_dir="$theme_path/art"
        mkdir -p "$art_dir"
        icon_path_prefix=$(realpath --relative-to="$theme_path" "$art_dir")

        # Crée les fichiers SVG
        cat > "$art_dir/wifi_on.bak.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36" stroke="#28a745" fill="none" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 16 C12 8, 24 8, 32 16" />
  <path d="M8 20 C14 14, 22 14, 28 20" />
  <path d="M12 24 C16 20, 20 20, 24 24" />
  <circle cx="18" cy="28" r="1.5" fill="#28a745" />
</svg>
EOF

        cat > "$art_dir/wifi_off.bak.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36" stroke="#dc3545" fill="none" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M4 16 C12 8, 24 8, 32 16" />
  <path d="M8 20 C14 14, 22 14, 28 20" />
  <path d="M12 24 C16 20, 20 20, 24 24" />
  <circle cx="18" cy="28" r="1.5" fill="#dc3545" />
  <line x1="6" y1="6" x2="30" y2="30" stroke="#dc3545" />
</svg>
EOF

        # Par défaut, active l'icône "on"
        cp "$art_dir/wifi_on.bak.svg" "$art_dir/wifi.svg"

        xml_block="
    <image name=\"wifi_icon\" extra=\"true\">
        <path>./$icon_path_prefix/wifi.svg</path>
        <pos>${WIFI_ICON_POS_X} ${WIFI_ICON_POS_Y}</pos>
        <origin>0.5 0.5</origin>
        <maxSize>${WIFI_ICON_SIZE} ${WIFI_ICON_SIZE}</maxSize>
        <zIndex>150</zIndex>
        <visible>true</visible>
    </image>"

        awk -v block="$xml_block" '/<view / { print; print block; next } { print }' "$theme_xml_file" > "${theme_xml_file}.tmp" && mv "${theme_xml_file}.tmp" "$theme_xml_file"
        touch "$theme_path/$PATCH_MARKER"
        progress_text+="Patched: $(basename "$theme_path")\n"
    done

    # Patch spécifique pour es-theme-nes-box/main.xml
    NESBOX_PATH="$THEMES_DIR/es-theme-nes-box"
    if [ -d "$NESBOX_PATH" ] && [ ! -f "$NESBOX_PATH/$MAINXML_MARKER" ]; then
        nesbox_xml="$NESBOX_PATH/main.xml"
        [ -f "$nesbox_xml" ] || return

        cp "$nesbox_xml" "${nesbox_xml}.bak"
        art_dir="$NESBOX_PATH/_art"
        mkdir -p "$art_dir"
        icon_path_prefix=$(realpath --relative-to="$NESBOX_PATH" "$art_dir")

        cp "$art_dir/wifi_on.bak.svg" "$art_dir/wifi.svg"

        xml_block="
    <image name=\"wifi_icon\" extra=\"true\">
        <path>./$icon_path_prefix/wifi.svg</path>
        <pos>${WIFI_ICON_POS_X} ${WIFI_ICON_POS_Y}</pos>
        <origin>0.5 0.5</origin>
        <maxSize>${WIFI_ICON_SIZE} ${WIFI_ICON_SIZE}</maxSize>
        <zIndex>150</zIndex>
        <visible>true</visible>
    </image>"

        awk -v block="$xml_block" '
            /<view name="system">/ || /<view name="detailed,video">/ || /<view name="basic">/ {
                print;
                print block;
                next;
            }
            { print }
        ' "$nesbox_xml" > "${nesbox_xml}.tmp" && mv "${nesbox_xml}.tmp" "$nesbox_xml"

        touch "$NESBOX_PATH/$MAINXML_MARKER"
        progress_text+="Patched: es-theme-nes-box\n"
    fi

    dialog --title "Done" --msgbox "Installation complete.\n\n$progress_text" 0 0 > "$CURR_TTY"
    create_updater_script
    create_systemd_service
    restart_es_and_exit
}

uninstall_icons() {
    dialog --title "Uninstalling Icons" --infobox "Restoring themes..." 4 45 > "$CURR_TTY"
    sleep 2
    local progress_text=""

    for theme_path in "$THEMES_DIR"/*; do
        [ -d "$theme_path" ] || continue

        xml="$theme_path/theme.xml"
        [ -f "$theme_path/$PATCH_MARKER" ] && [ -f "$xml.bak" ] && mv "$xml.bak" "$xml" && rm -f "$theme_path/$PATCH_MARKER"

        xml="$theme_path/main.xml"
        [ -f "$theme_path/$MAINXML_MARKER" ] && [ -f "$xml.bak" ] && mv "$xml.bak" "$xml" && rm -f "$theme_path/$MAINXML_MARKER"

        rm -f "$theme_path"/{art,_art}/wifi_*.svg

        progress_text+="Cleaned: $(basename "$theme_path")\n"
    done

    rm -f "$UPDATER_PATH"
    rm -f "$SERVICE_PATH"
    systemctl daemon-reload

    dialog --title "Uninstall Complete" --msgbox "$progress_text" 0 0 > "$CURR_TTY"
    restart_es_and_exit
}


# Function to enable Wi-Fi
enable_wifi() {
    dialog --infobox "Enabling WiFi..." 3 40 > $CURR_TTY
    sleep 2
    sudo nmcli radio wifi on
    update_wifi_status
    dialog --msgbox "Wi-Fi successfully activated!" 6 40 > "$CURR_TTY"
    printf "\033c" > "$CURR_TTY"
    pgrep -f gptokeyb | sudo xargs kill -9

    exit 0
}

# Function to disable Wi-Fi
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

# Set title based on Wi-Fi status
if [[ "$WIFI_STATUS" == "enabled" ]]; then
    TITLE="Wi-Fi: Enable"
else
    TITLE="Wi-Fi: Disable"
fi


# Display the main menu
MainMenu() {
  while true; do
    mainselection=(dialog \
        --backtitle "$BACKTITLE" \
        --title "Wi-Fi Manager - $TITLE" \
        --clear \
        --cancel-label "Exit" \
        --menu "Select an option:" 15 50 10)
    mainoptions=(
        1 "Install Wi-Fi icons"
        2 "Enable Wi-Fi"
        3 "Disable Wi-Fi"
        4 "Uninstall Wi-Fi icons"
    )
    mainchoices=$("${mainselection[@]}" "${mainoptions[@]}" 2>&1 > "$CURR_TTY")
    
    if [[ $? != 0 ]]; then
      exit 1
    fi

    case $mainchoices in
        1) install_icons ;;
        2) enable_wifi ;;      
        3) disable_wifiP ;;
        4) uninstall_icons ;;
        *) exit_script
    esac
  done
}

# Joystick control (if applicable)
sudo chmod 666 /dev/uinput
export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
pgrep -f gptokeyb > /dev/null && pgrep -f gptokeyb | sudo xargs kill -9
/opt/inttools/gptokeyb -1 "Wifi-Toggle.sh" -c "/opt/inttools/keys.gptk" > /dev/null 2>&1 &
printf "\033c" > $CURR_TTY

dialog --clear

trap exit_script EXIT SIGINT SIGTERM

# Launch the main menu
MainMenu