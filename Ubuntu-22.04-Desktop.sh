#!/bin/bash

# Copyright (C) 2021-2024 Thien Tran
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
    sudo -u nobody "$@"
}

# Compliance and updates
sudo systemctl mask debug-shell.service

sudo apt update -y
sudo apt full-upgrade -y
sudo apt autoremove -y

# Default to gcc-12 instead of gcc-11
sudo rm /usr/bin/gcc
sudo ln -s /usr/bin/gcc-12 /usr/bin/gcc

# Make home directory private
sudo chmod 700 /home/*

# Setting umask to 077
umask 077
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
sudo sed -i 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' /etc/login.defs
echo 'umask 077' | sudo tee --append /etc/profile

# Setup NTS
sudo systemctl disable systemd-timesyncd
sudo apt install -y curl chrony
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf
sudo systemctl restart chronyd

# Setup UFW
#UFW Snap is strictly confined, unlike its .deb counterpart
sudo apt purge -y ufw
sudo snap install ufw
sudo ufw enable

# Harden SSH
echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf

# Kernel hardening
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
sudo chmod 644 /etc/modprobe.d/30_security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf | sudo tee /etc/sysctl.d/990-security-misc.conf
sudo chmod 644 /etc/sysctl.d/990-security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf | sudo tee /etc/sysctl.d/30_silent-kernel-printk.conf
sudo chmod 644 /etc/sysctl.d/30_silent-kernel-printk.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf | sudo tee /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo chmod 644 /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sudo sysctl -p

# Rebuild initramfs
sudo update-initramfs -u

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf

# Setup dconf
sudo mkdir -p /etc/dconf/db/local.d/

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/automount-disable | sudo tee /etc/dconf/db/local.d/automount-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/automount-disable | sudo tee /etc/dconf/db/local.d/locks/automount-disable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/dconf/db/local.d/apport-disable | sudo tee /etc/dconf/db/local.d/apport-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/dconf/db/local.d/locks/apport-disable | sudo tee /etc/dconf/db/local.d/locks/apport-disable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/prefer-dark | sudo tee /etc/dconf/db/local.d/prefer-dark
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/button-layout | sudo tee /etc/dconf/db/local.d/button-layout
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/touchpad | sudo tee /etc/dconf/db/local.d/touchpad
sudo chmod 644 /etc/dconf/db/local.d/*
sudo dconf update

ubuntu-report -f send no
sudo systemctl stop apport.service
sudo systemctl disable apport.service
sudo systemctl mask apport.service
sudo systemctl stop whoopsie.service
sudo systemctl disable whoopsie.service
sudo systemctl mask whoopsie.service

# Update packages and firmware
sudo apt update -y
sudo apt full-upgrade -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

# Remove unneeded packages
sudo apt purge -y cups* eog gedit firefox* gnome-calculator gnome-characters* gnome-font-viewer gnome-logs gnome-power-manager gnome-shell-extension-prefs seahorse tcpdump whoopsie
sudo apt autoremove -y
sudo snap remove firefox

sudo rm -rf /usr/share/hplip

# Install packages that I use
sudo apt install -y gnome-console
sudo snap install gnome-text-editor loupe

# Setup Networking
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/00-macrandomize.conf | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/01-transient-hostname.conf | sudo tee /etc/NetworkManager/conf.d/01-transient-hostname.conf
sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''

# Installing tuned first here because virt-what is 1 of its dependencies anyways
sudo apt install tuned -y
virt_type=$(virt-what)
if [ "$virt_type" = '' ]; then
    output 'Virtualization: Bare Metal.'
elif [ "$virt_type" = 'openvz lxc' ]; then
    output 'Virtualization: OpenVZ 7.'
elif [ "$virt_type" = 'xen xen-hvm' ]; then
    output 'Virtualization: Xen-HVM.'
elif [ "$virt_type" = 'xen xen-hvm aws' ]; then
    output 'Virtualization: Xen-HVM on AWS.'
else
    output "Virtualization: $virt_type."
fi

# Setup tuned
if [ "$virt_type" = '' ]; then
  # Don't know whether using tuned would be a good idea on a laptop, power-profiles-daemon should be handling performance tuning IMO.
  sudo apt remove tuned -y
  sudo apt autoremove -y
else
  sudo tuned-adm profile virtual-guest
fi

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer