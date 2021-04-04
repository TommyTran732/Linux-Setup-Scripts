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
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
echo "umask 077" | sudo tee --append /etc/profile

#Make home directory private
sudo chmod 700 /home/*

#Disable crash reports
gsettings set com.ubuntu.update-notifier show-apport-crashes false
ubuntu-report -f send no
sudo systemctl stop apport.service
sudo systemctl disable apport.service
sudo systemctl mask apport.service
sudo systemctl stop whoopsie.service
sudo systemctl disable whoopsie.service
sudo systemctl mask whoopsie.service

#Disable ptrace
sudo sed -i 's/kernel.yama.ptrace_scope = 1/kernel.yama.ptrace_scope = 3/g' /etc/sysctl.d/10-ptrace.conf
sudo sysctl --load=/etc/sysctl.d/10-ptrace.conf

#Blacklist Firewire SBP2
echo "blacklist firewire-sbp2" | sudo tee /etc/modprobe.d/blacklist.conf

#Enable UFW
sudo ufw enable

#Update packages and firmware
sudo apt update
sudo apt upgrade -y
sudp apt autoremove -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

#Remove unneeded packages
#Note that I remove unattended upgrades because GNOME Software will be handling auto updates
sudo apt purge gnome-calculator *evince* *seahorse* *gedit* *yelp* gnome-screenshot gnome-power-manager eog gnome-logs gnome-characters gnome-shell-extension-desktop-icons gnome-font-viewer *file-roller* cups* printer-driver* network-manager-pptp* network-manager-openvpn* *nfs* apport* telnet *spice* tcpdump firefox* gnome-disk* gnome-initial-setup ubuntu-report popularity-contest whoopsie speech-dispatcher modemmanager avahi* gnome-shell-extension-ubuntu-dock mobile-broadband-provider-info ImageMagick* adcli libreoffice* ntfs* xfs* tracker* thermald sane* simple-scan *hangul* unattended-upgrades -y
sudo apt autoremove -y
sudo snap remove snap-store

#Install packages that I use
sudo add-apt-repository ppa:alexlarsson/flatpak -y
sudo apt update
sudo apt upgrade -y
sudo apt -y install neofetch gnome-software flatpak gnome-software-plugin-flatpak firejail apparmor-profiles apparmor-profiles-extra apparmor-utils gnome-tweak-tool git-core gnome-session-wayland libpam-pwquality python3-pip curl arc-theme nautilus

#Put all AppArmor profiles into enforcing mode
sudo aa-enforce /etc/apparmor. d/*

#Install Yubico Stuff
sudo apt -y install libpam-u2f
mkdir -p /home/${USER}/.config/Yubico

#Install IVPN
curl -fsSL https://repo.ivpn.net/stable/ubuntu/generic.gpg | sudo apt-key add -
curl -fsSL https://repo.ivpn.net/stable/ubuntu/generic.list | sudo tee /etc/apt/sources.list.d/ivpn.list
sudo chmod 644 /etc/apt/sources.list.d/ivpn.list
sudo apt update
sudo apt upgrade -y
sudo apt install ivpn-ui -y

#Install OpenSnitch
wget https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/opensnitch_1.3.6-1_amd64.deb
wget https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/python3-opensnitch-ui_1.3.6-1_all.deb
sudo dpkg -i opensnitch*.deb python3-opensnitch-ui*.deb
sudo apt -f install -y
rm -rf *opensnitch*

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

#Download GNOME shell theme
git clone https://github.com/i-mint/midnight.git
mkdir /home/${USER}/.themes
ln -s /home/${USER}/midnight/Midnight-* /home/${USER}/.themes/

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
gsettings set org.gnome.desktop.interface gtk-theme "Arc-dark"
flatpak upgrade -y

#Set Black GDM background
mkdir -p /home/${USER}/Pictures/Wallpapers/
wget https://wallpaperaccess.com/full/512679.jpg -O /home/${USER}/Pictures/Wallpapers/Black.png
wget github.com/thiggy01/change-gdm-background/raw/master/change-gdm-background
sudo chmod u+x /home/${USER}/change-gdm-background
output "Answer no to this or the script will get interupted"
sudo /home/${USER}/change-gdm-background /home/${USER}/Pictures/Wallpapers/Black.png

#Set Ubuntu 20.04 LTS Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/matt-mcnulty-nyc-2nd-ave.jpg'

#Enable Titlebar buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

#Enable GNOME shell extensions
gsettings set org.gnome.shell disable-user-extensions false

#Enable tap to click
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

#Setup GetExtensions
git clone https://github.com/ekistece/GetExtensions.git
pip3 install ./GetExtensions --user

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/lib/gdm3/gdm-disable-wayland"^#DRIVER=="nvidia", RUN+="/usr/lib/gdm3/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules

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
