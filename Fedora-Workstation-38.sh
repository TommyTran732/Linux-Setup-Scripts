#!/bin/bash

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead
#Customize it to your liking
#Run this script as your admin user, NOT root

#Variables
USER=$(whoami)
PARTITIONID=$(sudo cat /etc/crypttab | awk '{print $1}')
PARTITIONUUID=$(sudo blkid -s UUID -o value /dev/mapper/"${PARTITIONID}")

output(){
    echo -e '\e[36m'$1'\e[0m';
}

#Moving to the home directory
#Note that I always use /home/${USER} because gnome-terminal is wacky and sometimes doesn't load the environment variables in correctly (Right click somewhere in nautilus, click on open in terminal, then hit create new tab and you will see.)
cd /home/"${USER}" || exit

#Setting umask to 077
umask 077
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc
echo "umask 077" | sudo tee -a /etc/bashrc

#Make home directory private
chmod 700 /home/*

#Security kernel settings
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf

#Systemd Hardening
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo mkdir -p /etc/systemd/system/sshd.service.d
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf

echo "GSSAPIAuthentication no" | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
echo "VerifyHostKeyDNS yes" | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf

#Setup NTS
rm -rf /etc/chrony/chrony.conf
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf
sudo systemctl restart chronyd

#Setup Firewalld
sudo firewall-cmd --permanent --remove-port=1025-65535/udp
sudo firewall-cmd --permanent --remove-port=1025-65535/tcp
sudo firewall-cmd --permanent --remove-service=mdns
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --permanent --remove-service=samba-client
sudo firewall-cmd --reload

#Speed up DNF
sudo echo 'fastestmirror=1' | sudo tee -a /etc/dnf/dnf.conf
sudo echo 'deltarpm=true' | sudo tee -a /etc/dnf/dnf.conf
sudo echo 'countme=false' | sudo tee -a /etc/dnf/dnf.conf

#Update packages and firmware
sudo dnf upgrade -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

#Remove unneeded packages
sudo dnf -y remove abrt nm-connection-editor mozilla-filesystem chrome-gnome-shell quota* nmap-ncat virtualbox-guest-additions spice-vdagent nfs-utils teamd tcpdump sgpio ImageMagick* adcli libreoffice* lvm2 qemu-guest-agent hyperv* gnome-classic* baobab *kkc* *zhuyin* *pinyin* *evince* *yelp* ModemManager fedora-bookmarks fedora-chromium-config gnome-tour gnome-themes-extra gnome-shell-extension-background-logo gnome-screenshot gnome-remote-desktop gnome-font-viewer gnome-calculator NetworkManager-pptp-gnome NetworkManager-ssh-gnome NetworkManager-openconnect-gnome NetworkManager-openvpn-gnome NetworkManager-vpnc-gnome podman*  *libvirt* open-vm* *speech* sos totem gnome-characters firefox openssh-server dmidecode xorg-x11-drv-vmware xorg-x11-drv-amdgpu yajl words ibus-hangui vino openh264 realmd rsync net-snmp-libs net-tools traceroute mtr geolite2* gnome-boxes gnome-disk-utility gedit gnome-calendar cheese gnome-contacts rhythmbox gnome-screenshot gnome-maps gnome-weather gnome-logs ibus-typing-booster *m17n* gnome-clocks gnome-color-manager mlocate cyrus-sasl-plain cyrus-sasl-gssapi sssd* gnome-user* dos2unix kpartx rng-tools ppp* thermald *perl* gnome-shell-extension-apps-menu gnome-shell-extension-horizontal-workspaces gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list file-roller* sane* simple-scan *hangul* mediawriter *anthy*

#Disable openh264 repo
sudo dnf config-manager --set-disabled fedora-cisco-openh264 -y

#Install packages that I use
sudo dnf -y install gnome-console git-core flat-remix-theme gnome-shell-extension-appindicator gnome-shell-extension-background-blur gnome-shell-extension-dash-to-dock gnome-shell-extension-dash-to-dock gnome-shell-extension-no-overview

#Enable auto TRIM
sudo systemctl enable fstrim.timer

#Setup BTRFS layout and Timeshift
sudo mkdir /btrfs_pool
sudo mount -o subvolid=5 /dev/mapper/${PARTITIONID} /btrfs_pool
sudo mv /btrfs_pool/root /btrfs_pool/@
sudo mv /btrfs_pool/home /btrfs_pool/@home
sudo btrfs subvolume list /btrfs_pool
sudo sed -i 's/subvol=root/subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd:1,discard=async/' /etc/fstab
sudo sed -i 's/subvol=home/subvol=@home,ssd,noatime,space_cache,commit=120,compress=zstd:1,discard=async/' /etc/fstab
sudo echo "UUID=${PARTITIONUUID} /btrfs_pool             btrfs   subvolid=5,ssd,noatime,space_cache,commit=120,compress=zstd:1,discard=async,x-systemd.device-timeout=0   0 0" | sudo tee -a /etc/fstab
sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
sudo dnf -y install timeshift

#Randomize MAC address
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

#Disable transient hostname
sudo bash -c 'cat > /etc/NetworkManager/conf.d/00-macrandomize.conf' <<-'EOF'
[main]
hostname-mode=none
EOF

sudo systemctl restart NetworkManager
sudo hostnamectl hostname "localhost"

## The script is done. You can also remove gnome-terminal since gnome-console will replace it.