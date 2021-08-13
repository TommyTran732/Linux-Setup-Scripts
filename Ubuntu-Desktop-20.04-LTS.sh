#!/bin/bash

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead
#Customize it to your liking
#Run this script as your user, NOT root

#Note: BTRFS Setup is not included in this script. I highly recommend using encrypted ZFS instead: https://linsomniac.gitlab.io/post/2020-04-09-ubuntu-2004-encrypted-zfs/

#I also took some codes from https://www.ncsc.gov.uk/collection/end-user-device-security/platform-specific-guidance/ubuntu-18-04-lts as well

#Written by yours truly, Tomster

#Variables
USER=$(whoami)

output(){
    echo -e '\e[36m'$1'\e[0m';
}

#Moving to the home directory
#Note that I always use /home/${USER} because gnome-terminal is wacky and sometimes doesn't load the environment variables in correctly (Right click somewhere in nautilus, click on open in terminal, then hit create new tab and you will see.)
cd /home/"${USER}" || exit

#Setting umask to 077
umask 077
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
sudo sed -i 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' /etc/login.defs
echo "umask 077" | sudo tee --append /etc/profile

#Disable shell access for new users
sudo sed -ie '/^SHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/default/useradd
sudo sed -ie '/^DSHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/adduser.conf

#Prevent normal users from accessing su
sudo dpkg-statoverride --update --add root adm 4750 /bin/su

#Remove unnecessary permissions
sudo chmod o-w /var/cache
sudo chmod o-w /var/metrics

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

#Security kernel settings
sudo bash -c 'cat > /etc/sysctl.d/51-dmesg-restrict.conf' <<-'EOF'
kernel.dmesg_restrict = 1
EOF

sudo sysctl --load=/etc/sysctl.d/51-dmesg-restrict.conf

sudo bash -c 'cat > /etc/sysctl.d/51-kptr-restrict.conf' <<-'EOF'
kernel.kptr_restrict = 2
EOF

sudo sysctl --load=/etc/sysctl.d/51-kptr-restrict.conf

sudo bash -c 'cat > /etc/sysctl.d/51-kexec-restrict.conf' <<-'EOF'
kernel.kexec_load_disabled = 1
EOF

sudo sysctl --load=/etc/sysctl.d/51-kexec-restrict.conf

sudo bash -c 'cat > /etc/sysctl.d/10-security.conf' <<-'EOF'
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
net.core.bpf_jit_harden = 2
EOF

sudo sysctl --load=/etc/sysctl.d/10-security.conf.conf

#Blacklist Firewire SBP2
echo "blacklist firewire-sbp2" | sudo tee /etc/modprobe.d/blacklist.conf

#Enable UFW
sudo ufw enable

#Update packages and firmware
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

#Remove unneeded packages
#Note that I remove unattended upgrades because GNOME Software will be handling auto updates
sudo apt purge gnome-calculator *evince* *seahorse* *gedit* *yelp* gnome-screenshot gnome-power-manager eog gnome-logs gnome-characters gnome-shell-extension-desktop-icons gnome-font-viewer *file-roller* network-manager-pptp* network-manager-openvpn* *nfs* apport* telnet *spice* tcpdump firefox* gnome-disk* gnome-initial-setup ubuntu-report popularity-contest whoopsie speech-dispatcher modemmanager avahi* gnome-shell-extension-ubuntu-dock mobile-broadband-provider-info ImageMagick* adcli libreoffice* ntfs* xfs* tracker* thermald sane* simple-scan *hangul* unattended-upgrades ibus-table ubuntu-restricted-addons* python3-reportlab-accel* *remote-desktop* xserver-xephyr *printer-driver* info ftp* xul-ext-ubufox xcursor-themes wbritish wamerican strace anacron app-install-data-partner aspell* at-spi2-core brltty build-essential cron dmz-cursor-theme dosfstools ed genisoimage ltrace mailcap rsync bluez* cups* *printing* yaru-theme-gtk bluez* cups* *printing* yaru-theme-gtk network-manager-config-connectivity-ubuntu -y
sudo apt autoremove -y
sudo snap remove snap-store

#Install packages that I use
sudo add-apt-repository ppa:alexlarsson/flatpak -y
sudo apt update
sudo apt upgrade -y
sudo apt install neofetch gnome-software flatpak gnome-software-plugin-flatpak apparmor-profiles apparmor-profiles-extra apparmor-utils gnome-tweak-tool git-core libpam-pwquality python3-pip curl lm-sensors nvme-cli nautilus -y

#Put all AppArmor profiles into enforcing mode
sudo aa-enforce /etc/apparmor.d/*

#Install Yubico Stuff
sudo apt -y install libpam-u2f
mkdir -p /home/"${USER}"/.config/Yubico
sudo snap install yubioath-desktop

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
sudo chown -R "$USER":"$USER" /home/"${USER}"/.config/autostart

#Setting up Flatpak
flatpak remote-add --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
flatpak remote-add --user gnome-nightly https://nightly.gnome.org/gnome-nightly.flatpakrepo
flatpak remove --unused

#Install default applications
flatpak install flathub com.github.tchx84.Flatseal org.mozilla.firefox org.videolan.VLC org.gnome.eog org.gnome.Calendar org.gnome.Contacts org.gnome.FileRoller com.vscodium.codium -y

#Enable auto TRIM
sudo systemctl enable fstrim.timer

#Download GNOME shell theme
git clone https://github.com/i-mint/midnight.git
mkdir /home/"${USER}"/.themes
ln -s /home/"${USER}"/midnight/Midnight-* /home/"${USER}"/.themes/

#Download and set icon theme
git clone https://github.com/NicoHood/arc-icon-theme.git
mkdir /home/"${USER}"/.icons
ln -s /home/"${USER}"/arc-icon-theme/Arc /home/"${USER}"/.icons/
git clone https://github.com/tommytran732/Mojave-CT.git
ln -s /home/"${USER}"/Mojave-CT /home/"${USER}"/.icons/
sed -i 's/Inherits=Moka,Adwaita,gnome,hicolor/Inherits=Mojave-CT,Moka,Adwaita,gnome,hicolor/g' /home/"${USER}"/arc-icon-theme/Arc/index.theme
find /home/"${USER}"/arc-icon-theme -name '*[Tt]rash*' -exec rm {} \;
gsettings set org.gnome.desktop.interface icon-theme "Arc"

#Set GTK theme
sudo add-apt-repository ppa:daniruiz/flat-remix -y
sudo apt update
sudo apt install flat-remix-gtk -y
gsettings set org.gnome.desktop.interface gtk-theme "Flat-Remix-GTK-Blue-Dark"
flatpak upgrade -y

#Set Black GDM background
mkdir -p /home/"${USER}"/Pictures/Wallpapers/
wget https://wallpaperaccess.com/full/512679.jpg -O /home/"${USER}"/Pictures/Wallpapers/Black.png
wget github.com/thiggy01/change-gdm-background/raw/master/change-gdm-background
sudo chmod u+x /home/"${USER}"/change-gdm-background
output "Answer no to this or the script will get interupted"
sudo /home/"${USER}"/change-gdm-background /home/"${USER}"/Pictures/Wallpapers/Black.png

#Set Ubuntu 20.04 LTS Wallpaper
gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/matt-mcnulty-nyc-2nd-ave.jpg'

#Enable Titlebar buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

#Enable GNOME shell extensions
gsettings set org.gnome.shell disable-user-extensions false

#Enable tap to click
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true

#Enable touchpad while typing
gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing false

#Setup GetExtensions
git clone https://github.com/ekistece/GetExtensions.git
pip3 install ./GetExtensions --user

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/lib/gdm3/gdm-disable-wayland"^#DRIVER=="nvidia", RUN+="/usr/lib/gdm3/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules

#Signing ashmem kernel module
sudo kmodsign sha512 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der /lib/modules/`uname -r`/kernel/drivers/staging/android/ashmem_linux.ko

#Kind of an ugly hack, but since I use Nvidia and it needs to sign the Nvidia driver everytime theres a kernel update anyways, so I am doing this for now
sudo bash -c 'cat > /etc/dkms/sign_helper.sh' <<-'EOF'
#!/bin/sh
/lib/modules/"$1"/build/scripts/sign-file sha512 /root/mok.priv /root/mok.der "$2"
echo "kmodsign sha512 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der /lib/modules/`uname -r`/kernel/drivers/staging/android/ashmem_linux.ko"
EOF

sudo chmod 755 /etc/dkms/sign_helper.sh

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
