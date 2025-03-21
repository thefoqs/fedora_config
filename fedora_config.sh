#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with sudo or as the root user." 1>&2
   exit 1
fi

# Set PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Dialog dimensions
HEIGHT=20
WIDTH=90
CHOICE_HEIGHT=10

# Titles and messages
BACKTITLE="Fedora_config v1.0 - A Fedora Post Install Setup Util for GNOME - Forked from https://github.com/smittix/fedorable"
TITLE="Please Make a Selection"
MENU="Please Choose one of the following options:"

# Other variables
OH_MY_ZSH_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
LOG_FILE="setup_log.txt"

# Log function
log_action() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Check for dialog installation
if ! rpm -q dialog &>/dev/null; then
    sudo dnf install -y dialog || { log_action "Failed to install dialog. Exiting."; exit 1; }
    log_action "Installed dialog."
fi

# Options for the menu
OPTIONS=(
    1 "Enable RPM Fusion - Enables RPM Fusion Repositories"
    2 "Update Firmware - For systems that support firmware delivery"
    3 "Speed up DNF - Sets max parallel downloads to 10"
    4 "Enable Flathub - Enables FlatHub & installs packages located in flatpak-packages.txt"
    5 "Install Software - Installs software located in dnf-packages.txt"
    6 "Install Oh-My-ZSH - Installs Oh-My-ZSH"
    7 "Install Codecs"
    8 "Install Nvidia - Install akmod Nvidia drivers"
    9 "Customise - Configures system settings"
    10 "Quit"
)

# Function to display notifications
notify() {
    local message=$1
    local expire_time=${2:-10}
    if command -v notify-send &>/dev/null; then
        notify-send "$message" --expire-time="$expire_time"
    fi
    log_action "$message"
}

# Function to handle RPM Fusion setup
enable_rpm_fusion() {
    echo "Enabling RPM Fusion"
    sudo dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    sudo dnf upgrade --refresh -y
    sudo dnf group upgrade -y core
    sudo dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted dnf-plugins-core
    notify "RPM Fusion Enabled"
}

# Function to update firmware
update_firmware() {
    echo "Updating System Firmware"
    sudo fwupdmgr get-devices
    sudo fwupdmgr refresh --force
    sudo fwupdmgr get-updates
    sudo fwupdmgr update
    notify "System Firmware Updated"
}

# Function to speed up DNF
speed_up_dnf() {
    echo "Speeding Up DNF"
    echo 'max_parallel_downloads=10' | sudo tee -a /etc/dnf/dnf.conf
    notify "Your DNF config has now been amended"
}

# Function to enable Flatpak
enable_flatpak() {
    echo "Enabling Flatpak"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak update -y
    if [ -f ./assets/flatpak-install.sh ]; then
        source ./assets/flatpak-install.sh
    else
        log_action "flatpak-install.sh not found"
    fi
    notify "Flatpak has now been enabled"
}

# Function to install software
install_software() {
    echo "Installing Software"
    if [ -f ./assets/dnf-packages.txt ]; then
        sudo dnf install -y $(cat ./assets/dnf-packages.txt)
        notify "Software has been installed"
    else
        log_action "dnf-packages.txt not found"
    fi
}

# Function to install Oh-My-Zsh and Starship
install_oh_my_zsh() {
    echo "Installing Oh-My-Zsh"
    sudo dnf install -y zsh curl util-linux-user
    sudo -u "$SUDO_USER" sh -c "$(curl -fsSL $OH_MY_ZSH_URL)" "" --unattended
    sudo -u "$SUDO_USER" chsh -s "$(which zsh)"
    notify "Oh-My-Zsh is ready to rock n roll"
}

# Function to install extras
install_extras() {
    echo "Installing Extras"
    sudo dnf groupupdate -y sound-and-video
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    sudo dnf install -y libdvdcss
    sudo dnf install -y gstreamer1-plugins-{bad-\*,good-\*,ugly-\*,base} gstreamer1-libav --exclude=gstreamer1-plugins-bad-free-devel ffmpeg gstreamer-ffmpeg
    sudo dnf install -y lame\* --exclude=lame-devel
    sudo dnf group upgrade -y --with-optional Multimedia
    sudo dnf config-manager --set-enabled fedora-cisco-openh264
    sudo dnf install -y gstreamer1-plugin-openh264 mozilla-openh264
    notify "All done"
}

# Function to install Nvidia drivers
install_nvidia() {
    echo "Installing Nvidia Driver Akmod-Nvidia"
    sudo dnf install -y akmod-nvidia
    notify "Please wait 5 minutes until rebooting"
}

# Customization Functions
# Function to set the hostname
set_hostname() {
    hostname=$(dialog --inputbox "Enter new hostname:" 10 50 3>&1 1>&2 2>&3 3>&-)
    if [ ! -z "$hostname" ]; then
        sudo hostnamectl set-hostname "$hostname"
        dialog --msgbox "Hostname set to $hostname" 10 50
    else
        dialog --msgbox "Hostname not set. Input was empty." 10 50
    fi
}

# Main loop
check_permissions  # Ensure the script is run with appropriate permissions
while true; do
    CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --nocancel \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

    clear
    case $CHOICE in
        1) enable_rpm_fusion ;;
        2) update_firmware ;;
        3) speed_up_dnf ;;
        4) enable_flatpak ;;
        5) install_software ;;
        6) install_oh_my_zsh ;;
        7) install_extras ;;
        8) install_nvidia ;;
        9)
            # Customization menu
            while true; do
                CUSTOM_CHOICE=$(dialog --clear --backtitle "Fedora System Configuration" \
                    --title "Customization Menu" \
                    --menu "Choose an option:" 15 50 8 \
                    1 "Set Hostname" \
                    2 "Exit" \
                    3>&1 1>&2 2>&3)

                case $CUSTOM_CHOICE in
                    1) set_hostname ;;
                    2) break ;;
                    *) dialog --msgbox "Invalid option. Please try again." 10 50 ;;
                esac
            done
            ;;
        10) log_action "User chose to quit the script."; exit 0 ;;
        *) log_action "Invalid option selected: $CHOICE";;
    esac
done
