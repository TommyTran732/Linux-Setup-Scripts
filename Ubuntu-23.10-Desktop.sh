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

# Setup Networking
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/00-macrandomize.conf | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/01-transient-hostname.conf | sudo tee /etc/NetworkManager/conf.d/01-transient-hostname.conf
sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''

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
umask 022

sudo mkdir -p /etc/dconf/db/local.d/locks

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/automount-disable | sudo tee /etc/dconf/db/local.d/automount-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/automount-disable | sudo tee /etc/dconf/db/local.d/locks/automount-disable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/apport-disable | sudo tee /etc/dconf/db/local.d/apport-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/apport-disable | sudo tee /etc/dconf/db/local.d/locks/apport-disable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/touchpad | sudo tee /etc/dconf/db/local.d/touchpad

sudo dconf update
umask 077

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
sudo apt purge -y apport baobab cups* eog gedit firefox* gnome-calculator gnome-characters* gnome-clocks gnome-font-viewer gnome-logs gnome-power-manager gnome-shell-extension-prefs libreoffice* seahorse tcpdump whoopsie
sudo apt autoremove -y
sudo snap remove firefox

sudo rm -rf /usr/share/hplip

# Install packages that I use
sudo apt install -y gnome-console
sudo snap install gnome-text-editor loupe

# Rosetta setup
if [ -f /media/psf/RosettaLinux/rosetta ]; then
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/rosetta-sources.list | sudo tee /etc/apt/sources.list
    rm -rf /etc/apt/sources.list.d/proposed.list
fi

sudo dpkg --add-architecture amd64
sudo apt update
sudo apt full-upgrade -y

# Install Microsoft Edge if x86_64
MACHINE_TYPE=$(uname -m)
if [ "${MACHINE_TYPE}" == 'x86_64' ] || [ -f /media/psf/RosettaLinux/rosetta ]; then
    output 'x86_64 machine, installing Microsoft Edge.'
    unpriv curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg
    sudo chmod 644 /usr/share/keyrings/microsoft.gpg
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/microsoft-edge.list | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
    sudo chmod 644 /etc/apt/sources.list.d/microsoft-edge.list
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt install -y microsoft-edge-stable
    sudo mkdir -p /etc/opt/edge/policies/managed/ /etc/opt/edge/policies/recommended/
    sudo chmod -R 755 /etc/opt/edge
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/managed.json | sudo tee /etc/opt/edge/policies/managed/managed.json
    sudo chmod 644 /etc/opt/edge/policies/managed/managed.json
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/recommended.json | sudo tee /etc/opt/edge/policies/recommended/recommended.json
    sudo chmod 644 /etc/opt/edge/policies/managed/managed.json /etc/opt/edge/policies/recommended/recommended.json
fi

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer

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