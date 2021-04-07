#This is a quick script to run after any Ubuntu update after 20.04 (tested on 20.10 and 21.04)

#Variables
USER=$(whoami)

#Fixing umask
umask 077
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
sudo sed -i 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' /etc/login.defs
sudo sed -i 's/HOME_MODE       0750/HOME_MODE       0700/g' /etc/login.defs

#Remove unneeded packages
#Note that I remove unattended upgrades because GNOME Software will be handling auto updates
sudo apt purge gnome-calculator *evince* *seahorse* *gedit* *yelp* gnome-screenshot gnome-power-manager eog gnome-logs gnome-characters gnome-shell-extension-desktop-icons gnome-font-viewer *file-roller* network-manager-pptp* network-manager-openvpn* *nfs* apport* telnet *spice* tcpdump firefox* gnome-disk* gnome-initial-setup ubuntu-report popularity-contest whoopsie speech-dispatcher modemmanager avahi* gnome-shell-extension-ubuntu-dock mobile-broadband-provider-info ImageMagick* adcli libreoffice* ntfs* xfs* tracker* thermald sane* simple-scan *hangul* unattended-upgrades ibus-table python3-reportlab-accel* *remote-desktop* xserver-xephyr *printer-driver* info ftp* xul-ext-ubufox xcursor-themes wbritish wamerican strace anacron app-install-data-partner aspell* at-spi2-core brltty build-essential cron dmz-cursor-theme dosfstools ed genisoimage ltrace mailcap rsync bluez* cups* *printing* yaru-theme-gtk bluez* cups* *printing* yaru-theme-gtk network-manager-config-connectivity-ubuntu -y

#Install gnome extensions (most extensions are available in the repos now)
sudo apt install gnome-shell-extensions gnome-shell-extension-dashtodock gnome-shell-extension-freon gnome-shell-extension-system-monitor gnome-shell-extension-weather nautilus
sudo rm -rf /usr/share/xsessions/gnome-classic.desktop

#Remove GetExtensions
pip3 uninstall GetExtensions
rm -rf /home/${USER}/.local/lib/python*

#Reinstall OpenSnitch
wget https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/opensnitch_1.3.6-1_amd64.deb
wget https://github.com/evilsocket/opensnitch/releases/download/v1.3.6/python3-opensnitch-ui_1.3.6-1_all.deb
sudo dpkg -i opensnitch*.deb python3-opensnitch-ui*.deb
sudo apt -f install -y
rm -rf *opensnitch*
sudo chown -R $USER:$USER /home/${USER}/.config/autostart

#Put all AppArmor profiles into enforcing mode
sudo aa-enforce /etc/apparmor.d/*

#Update flatpak
flatpak update
flatpak remove --unused

#Update snap
sudo snap refresh

#Signing ashmem kernel module
sudo kmodsign sha512 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der /lib/modules/`uname -r`/kernel/drivers/staging/android/ashmem_linux.ko

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^#DDRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules
