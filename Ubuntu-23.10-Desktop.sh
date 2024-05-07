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

install_options(){
    output "Are you using a Parallels Virtual Machine?"
    output "[1] Yes"
    output "[2] No"
    read -r choice
    case $choice in
        1 ) parallels=1
            ;;
        2 ) parallels=0
            ;;
        * ) output "You did not enter a valid selection."
            install_options
    esac
}

install_options

# Compliance and updates
sudo systemctl mask debug-shell.service

## Avoid phased updates
sudo apt install curl -y
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/apt.conf.d/99sane-upgrades | sudo tee /etc/apt/apt.conf.d/99sane-upgrades
sudo chmod 644 /etc/apt/apt.conf.d/99sane-upgrades

sudo apt update -y
sudo apt full-upgrade -y
sudo apt autoremove -y

# Make home directory private
sudo chmod 700 /home/*

# Setting umask to 077
umask 077
sudo sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sudo sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs
sudo sed -i 's/USERGROUPS_ENAB yes/USERGROUPS_ENAB no/g' /etc/login.defs
echo 'umask 077' | sudo tee --append /etc/profile

# Setup NTS
sudo systemctl disable --now systemd-timesyncd
sudo systemctl mask systemd-timesyncd

if [ "${parallels}" = "0" ]; then
    sudo apt install -y chrony
    unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf
    sudo systemctl restart chronyd
fi

# Harden SSH
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf

# Kernel hardening
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
sudo chmod 644 /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/#install msr/install msr/g' /etc/modprobe.d/30_security-misc.conf
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

# Disable coredump
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf

# Update GRUB config
# shellcheck disable=SC2016
echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off lockdown=confidentiality"' | sudo tee -a /etc/grub.d/40_custom
sudo update-grub

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf

# Disable XWayland
umask 022
sudo mkdir -p /etc/systemd/user/org.gnome.Shell@wayland.service.d
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/user/org.gnome.Shell%40wayland.service.d/override.conf | sudo tee /etc/systemd/user/org.gnome.Shell@wayland.service.d/override.conf
umask 077

# Setup dconf
umask 022

sudo mkdir -p /etc/dconf/db/local.d/locks

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/apport-disable | sudo tee /etc/dconf/db/local.d/locks/apport-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/automount-disable | sudo tee /etc/dconf/db/local.d/locks/automount-disable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/apport-disable | sudo tee /etc/dconf/db/local.d/apport-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/automount-disable | sudo tee /etc/dconf/db/local.d/automount-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/button-layout | sudo tee /etc/dconf/db/local.d/button-layout
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/prefer-dark | sudo tee /etc/dconf/db/local.d/prefer-dark
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/privacy | sudo tee /etc/dconf/db/local.d/privacy
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/touchpad | sudo tee /etc/dconf/db/local.d/touchpad

sudo dconf update
umask 077

ubuntu-report -f send no
sudo systemctl disable --now apport.service
sudo systemctl mask apport.service
sudo systemctl disable --now whoopsie.service
sudo systemctl mask whoopsie.service
sudo systemctl disable --now whoopsie.path
sudo systemctl mask whoopsie.path

# Update packages and firmware
sudo apt update -y
sudo apt full-upgrade -y
sudo fwupdmgr get-devices
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates -y
sudo fwupdmgr update -y

# Remove unneeded packages
sudo apt purge -y apport baobab cups* eog gedit firefox* gnome-calculator gnome-characters* gnome-clocks gnome-font-viewer gnome-logs gnome-power-manager gnome-shell-extension-prefs gnome-text-editor libreoffice* seahorse tcpdump whoopsie
sudo apt autoremove -y
sudo snap remove firefox snap-store

sudo rm -rf /usr/share/hplip

# Install packages that I use
sudo apt install -y gnome-console gnome-software-plugin-flatpak
sudo snap install gnome-text-editor

# Setup Flatpak
sudo flatpak override --system --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions
flatpak override --user --nosocket=x11 --nosocket=fallback-x11 --nosocket=pulseaudio --nosocket=session-bus --nosocket=system-bus --unshare=network --unshare=ipc --nofilesystem=host:reset --nodevice=shm --nodevice=all --no-talk-name=org.freedesktop.Flatpak --no-talk-name=org.freedesktop.systemd1 --no-talk-name=ca.desrt.dconf --no-talk-name=org.gnome.Shell.Extensions
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak --user install org.gnome.Extensions com.github.tchx84.Flatseal org.gnome.Loupe -y
flatpak --user override com.github.tchx84.Flatseal --filesystem=/var/lib/flatpak/app:ro --filesystem=xdg-data/flatpak/app:ro --filesystem=xdg-data/flatpak/overrides:create
flatpak --user override org.gnome.Extensions --talk-name=org.gnome.Shell.Extensions
flatpak update -y

# Rosetta setup
if [ -f /media/psf/RosettaLinux/rosetta ] || [ -f /media/rosetta/rosetta ]; then
    if [ -f /media/rosetta/rosetta ]; then
        sudo /usr/sbin/update-binfmts --install rosetta /media/rosetta/rosetta --magic "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00" --mask "\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff" --credentials yes --preserve no --fix-binary yes
    fi
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/rosetta-sources.list | sudo tee /etc/apt/sources.list
    rm -rf /etc/apt/sources.list.d/proposed.list
    sudo dpkg --add-architecture amd64
    sudo apt update
    sudo apt full-upgrade -y
fi

# Install Microsoft Edge if x86_64
MACHINE_TYPE=$(uname -m)
if [ "${MACHINE_TYPE}" == 'x86_64' ] || [ -f /media/psf/RosettaLinux/rosetta ] || [ -f /media/rosetta/rosetta ]; then
    umask 022
    output 'x86_64 machine, installing Microsoft Edge.'
    unpriv curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/microsoft-edge.list | sudo tee /etc/apt/sources.list.d/microsoft-edge.list
    sudo apt update
    sudo apt full-upgrade -y
    sudo apt install -y microsoft-edge-stable
    sudo mkdir -p /etc/opt/edge/policies/managed/ /etc/opt/edge/policies/recommended/
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/managed.json | sudo tee /etc/opt/edge/policies/managed/managed.json
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/recommended.json | sudo tee /etc/opt/edge/policies/recommended/recommended.json
    if [ -f /media/psf/RosettaLinux/rosetta ] || [ -f /media/rosetta/rosetta ]; then
        #Edge does not seem to work on Wayland with Rosetta - dunno why yet. Probably missing libraries?
        sudo rm -rf /etc/systemd/user/org.gnome.Shell@wayland.service.d
    else
        sudo mkdir -p /usr/local/share/applications
        sed 's/^Exec=\/usr\/bin\/microsoft-edge-stable/& --ozone-platform=wayland --start-maximized/g' /usr/share/applications/microsoft-edge.desktop | sudo tee /usr/local/share/applications/microsoft-edge.desktop
    fi
    umask 077
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
    if [ "$virt_type" = 'kvm' ]; then
        sudo apt install qemu-guest-agent -y
    fi
    sudo tuned-adm profile virtual-guest
fi

# Setup Networking

# UFW Snap is strictly confined, unlike its .deb counterpart
sudo apt purge -y ufw
sudo snap install ufw
sudo ufw enable

unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/00-macrandomize.conf | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/01-transient-hostname.conf | sudo tee /etc/NetworkManager/conf.d/01-transient-hostname.conf
sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager