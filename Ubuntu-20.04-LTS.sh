#!/bin/bash

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead
#Customize it to your liking
#Run this script as your user, NOT root

#Note: BTRFS Setup is not included in this script. I highly recommend using encrypted ZFS instead: https://linsomniac.gitlab.io/post/2020-04-09-ubuntu-2004-encrypted-zfs/

#Written by yours truly, Tomster

#Variables
USER=$(whoami)

output(){
    echo -e '\e[36m'$1'\e[0m';
}

#Moving to the home directory
#Note that I always use /home/${USER} because gnome-terminal is wacky and sometimes doesn't load the environment variables in correctly (Right click somewhere in nautilus, click on open in terminal, then hit create new tab and you will see.)
cd /home/${USER} || exit

#Setting umask to 077
umask 077
sudo sed -i 's/UMASK		022/UMASK		077/g' /etc/login.defs
echo "umask 077" | sudo tee --append /etc/profile

#Make home directory private
chmod -R o-rwx /home/${USER}

#Disable ptrace
echo "kernel.yama.ptrace_scope = 3" | sudo tee /etc/sysctl.d/10-default-yama-scope.conf
sudo sysctl --load=/etc/sysctl.d/10-default-yama-scope.conf

#Enable UFW
sudo ufw enable

#Update packages and firmware
sudo apt update
sudo apt upgrade -y
sudp apt autoremove -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update -y

#Remove unneeded packages
sudo apt purge gnome-calculator *evince* *seahorse* *gedit* *yelp* gnome-screenshot gnome-power-manager eog gnome-logs gnome-characters gnome-shell-extension-desktop-icons gnome-font-viewer *file-roller* cups* printer-driver* network-manager-pptp* network-manager-openvpn* *nfs* aaport* telnet *spice* tcpdump firefox* gnome-disk* gnome-initial-setup ubuntu-report popularity-contest whoopsie speech-dispatcher modemmanager avahi* gnome-shell-extension-ubuntu-dock mobile-broadband-provider-info ImageMagick* adcli libreoffice* ntfs* xfs* tracker* thermald sane* simple-scan *hangul* -y
sudo apt autoremove -y
sudo snap remove snap-store

#Install packages that I use
sudo add-apt-repository ppa:alexlarsson/flatpak -y
sudo apt update
sudo apt upgrade -y
sudo apt -y install neofetch gnome-software flatpak gnome-software-plugin-flatpak firejail apparmor-profiles apparmor-profiles-extra apparmor-utils gnome-tweak-tool git-core sudo apt install gnome-session-wayland

#Put all AppArmor profiles into enforcing mode
sudo aa-enforce /etc/apparmor. d/*

#Install Yubico Stuff
sudo apt -y install yubikey-manager pam-u2f pamu2fcfg
mkdir -p /home/${USER}/.config/Yubico

#Install IVPN
curl -fsSL https://repo.ivpn.net/stable/ubuntu/generic.gpg | sudo apt-key add - 
curl -fsSL https://repo.ivpn.net/stable/ubuntu/generic.list | sudo tee /etc/apt/sources.list.d/ivpn.list 
sudo chmod 644 /etc/apt/sources.list.d/ivpn.list
sudo apt update
sudo apt upgrade -y
sudo apt install ivpn-ui -y

#Install OpenSnitch
sudo apt install -y https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/opensnitch_1.3.6-1_amd64.deb
sudo apt install -y https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/python3-opensnitch-ui_1.3.6-1_all.deb
sudo chmod -R $USER:USER /home/${USER}/.config/autostart

#Setup VSCodium
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/vscodium.gpg 
sudo chmod 644 /etc/apt/trusted.gpg.d/vscodium.gpg
echo 'deb https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/debs/ vscodium main' | sudo tee --append /etc/apt/sources.list.d/vscodium.list 
sudo chmod 644 /etc/apt/sources.list.d/vscodium.list
sudo apt update 
sudo apt upgrade -y
sudo apt install -y codium
sudo cp /etc/firejail/vscodium.profile /etc/firejail/codium.profile
sudo chmod 644 /etc/firejail/codium.profile

#Setting up Flatpak
flatpak remote-add --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remove --unused

#Install default applications
flatpak install flathub com.github.tchx84.Flatseal org.mozilla.firefox org.videolan.VLC org.gnome.eog org.gnome.Calendar org.gnome.Contacts org.gnome.FileRoller com.yubico.yubioath -y

#Enable auto TRIM
sudo systemctl enable fstrim.timer

#Enable Firejail
sudo firecfg

#Download and set icon theme
git clone https://github.com/NicoHood/arc-icon-theme.git
mkdir /home/${USER}/.icons 
ln -s /home/${USER}/arc-icon-theme/Arc /home/${USER}/.icons/
git clone https://github.com/zayronxio/Mojave-CT.git
ln -s /home/${USER}/Mojave-CT /home/${USER}/.icons/
sed -i 's/Inherits=Moka,Adwaita,gnome,hicolor/Inherits=Mojave-CT,Moka,Adwaita,gnome,hicolor/g' /home/${USER}/arc-icon-theme/Arc/index.theme
find /home/${USER}/arc-icon-theme -name '*[Tt]rash*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Nn]autilus*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Ss]ettings*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Tt]weak*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Ss]oftware*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Gg]nome.[Bb]oxes*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Ss]team*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Tt]hunderbird*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Mm]inecraft*' -exec rm {} \;
find /home/${USER}/Mojave-CT -name '*[Ee]piphany*' -exec rm {} \;
gsettings set org.gnome.desktop.interface icon-theme "Arc"

#Set GTK theme
gsettings set org.gnome.desktop.interface gtk-theme "Yaru-Dark"
flatpak upgrade -y

#Set Ubuntu 20.04 LTS Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/matt-mcnulty-nyc-2nd-ave.jpg'

#Enable Titlebar buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

#Enable GNOME shell extensions
gsettings set org.gnome.shell disable-user-extensions false

#Enable tap to click
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^#DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules

#Randomize MAC address
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
connection.stable-id=${CONNECTION}/${BOOT}
EOF

sudo systemctl restart NetworkManager


