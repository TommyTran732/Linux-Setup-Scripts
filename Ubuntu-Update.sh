#This is a quick script to run after any Ubuntu update after 20.04 (tested on 20.10 and 21.04)

#Remove unneeded packages
#Note that I remove unattended upgrades because GNOME Software will be handling auto updates
sudo apt purge gnome-calculator *evince* *seahorse* *gedit* *yelp* gnome-screenshot gnome-power-manager eog gnome-logs gnome-characters gnome-shell-extension-desktop-icons gnome-font-viewer *file-roller* network-manager-pptp* network-manager-openvpn* *nfs* apport* telnet *spice* tcpdump firefox* gnome-disk* gnome-initial-setup ubuntu-report popularity-contest whoopsie speech-dispatcher modemmanager avahi* gnome-shell-extension-ubuntu-dock mobile-broadband-provider-info ImageMagick* adcli libreoffice* ntfs* xfs* tracker* thermald sane* simple-scan *hangul* unattended-upgrades ibus-table ubuntu-restricted-addons* python3-reportlab-accel* *remote-desktop* xserver-xephyr -y

#Fix up dependencies for OpenSnitch
sudo apt install python3-grpcio python3-slugify -y

#Update flatpak
flatpak update
flatpak remove --unused

#Update snap
sudo snap refresh

#Signing ashmem kernel module
sudo kmodsign sha512 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der /lib/modules/`uname -r`/kernel/drivers/staging/android/ashmem_linux.ko

#Reenable Wayland... They are working to support it, and if you aren't gaming you shouldn't stay on x11 anyways
sudo sed -i 's^DRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^#DDRIVER=="nvidia", RUN+="/usr/libexec/gdm-disable-wayland"^g' /usr/lib/udev/rules.d/61-gdm.rules
