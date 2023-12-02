#!/bin/bash

# Copyright (C) 2023 Thien Tran
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
##The script assumes you already have Ubuntu Pro activated

output(){
    echo -e '\e[36m'$1'\e[0m';
}

#Compliance and updates
sudo ua enable usg
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y usg
sudo apt autoremove -y
sudo usg fix cis_level2_workstation

# Remove AIDE
sudo apt purge -y aide*

# Allow su which is disabled by CIS
sudo sed -i 's/auth required pam_wheel.so use_uid group=sugroup//g' /etc/pam.d/su

# Setting umask to 077
umask 077
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
sudo sed -i 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' /etc/login.defs
echo "umask 077" | sudo tee --append /etc/profile

# Setup NTS
sudo systemctl disable systemd-timesyncd
sudo apt install -y curl chrony
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf
sudo systemctl restart chronyd

# Setup UFW
#UFW Snap is strictly confined, unlike its .deb counterpart
sudo apt purge -y ufw
sudo snap install ufw
sudo ufw enable

# Harden SSH
echo "GSSAPIAuthentication no" | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
echo "VerifyHostKeyDNS yes" | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf

# Kernel hardening
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf -o /etc/sysctl.d/990-security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sudo sysctl -p

# Rebuild initramfs
sudo update-initramfs -u

# Disable telemetry
sudo systemctl stop apport.service
sudo systemctl disable apport.service
sudo systemctl mask apport.service
sudo systemctl stop whoopsie.service
sudo systemctl disable whoopsie.service
sudo systemctl mask whoopsie.service

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf

# Disable automount
curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/dconf/db/local.d/automount-disable -o /etc/dconf/db/local.d/automount-disable
curl curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/dconf/db/local.d/locks/automount-disable -o /etc/dconf/db/local.d/locks/automount-disable
sudo dconf update

# Disable crash reports
echo '[com/ubuntu/update-notifier]
show-apport-crashes=false' | sudo tee /etc/dconf/db/local.d/disable-apport-crashes

echo 'com/ubuntu/update-notifier/show-apport-crashes' | sudo tee /etc/dconf/db/local.d/locks/disable-apport-crashes

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

# Install packages that I use
sudo apt install -y git-core gnome-text-editor
sudo snap install eog

# Setup Networking
sudo curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/NetworkManager/conf.d/00-macrandomize.conf -o /etc/NetworkManager/conf.d/00-macrandomize.conf
sudo curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Script/main/etc/NetworkManager/conf.d/01-transient-hostname.conf -o /etc/NetworkManager/conf.d/01-transient-hostname.conf
sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''

# Enable fstrim.timer
sudo apt install tuned -y
sudo systemctl enable --now fstrim.timer
