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

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
    sudo -u nobody "$@"
}

# Compliance
sudo rm /etc/systemd/system/ctrl-alt-del.target
sudo systemctl mask ctrl-alt-del.target
sudo systemctl mask debug-shell.service
sudo systemctl mask kdump.service
echo 'CtrlAltDelBurstAction=none' | sudo tee -a /etc/systemd/system.conf

# Setting umask to 077
umask 077
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc
echo 'umask 077' | sudo tee -a /etc/bashrc

# Make home directory private
chmod 700 /home/*

# Setup NTS
sudo rm -rf /etc/chrony/chrony.conf
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf
echo '# Command-line options for chronyd
OPTIONS="-F 1"' | sudo tee /etc/sysconfig/chronyd

sudo systemctl restart chronyd

# Setup Networking
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/00-macrandomize.conf | sudo tee /etc/NetworkManager/conf.d/00-macrandomize.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/NetworkManager/conf.d/01-transient-hostname.conf | sudo tee /etc/NetworkManager/conf.d/01-transient-hostname.conf
sudo nmcli general reload conf
sudo hostnamectl hostname 'localhost'
sudo hostnamectl --transient hostname ''
sudo firewall-cmd --set-default-zone=block
sudo firewall-cmd --permanent --add-service=dhcpv6-client
sudo firewall-cmd --reload
sudo firewall-cmd --lockdown-on

# Harden SSH
echo 'GSSAPIAuthentication no' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
echo 'VerifyHostKeyDNS yes' | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf

# Security kernel settings
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf | sudo tee /etc/sysctl.d/990-security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf | sudo tee /etc/sysctl.d/30_silent-kernel-printk.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf | sudo tee /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=1/g' /etc/sysctl.d/990-security-misc.conf
sudo grubby --update-kernel=ALL --args='spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt tsx=off tsx_async_abort=full,nosmt kvm.nx_huge_pages=force nosmt=force l1d_flush=on mmio_stale_data=full,nosmt random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=isolation_force efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on extra_latent_entropy debugfs=off'
sudo dracut -f
sudo sysctl -p

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl restart NetworkManager

# Disable automount
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/automount-disable | sudo tee /etc/dconf/db/local.d/automount-disable
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dconf/db/local.d/locks/automount-disable | sudo tee /etc/dconf/db/local.d/locks/automount-disable
sudo dconf update

# Setup ZRAM
echo -e '[zram0]\nzram-fraction = 1\nmax-zram-size = 8192\ncompression-algorithm = zstd' | sudo tee /etc/systemd/zram-generator.conf

# Speed up DNF
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dnf/dnf.conf | sudo tee /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Remove firefox packages
sudo dnf -y remove fedora-bookmarks fedora-chromium-config firefox mozilla-filesystem

# Remove Network + hardware tools packages
sudo dnf -y remove '*cups' nmap-ncat nfs-utils nmap-ncat openssh-server net-snmp-libs net-tools opensc traceroute rsync tcpdump teamd geolite2* mtr dmidecode sgpio

#Remove support for some languages and spelling
sudo dnf -y remove ibus-typing-booster '*speech*' '*zhuyin*' '*pinyin*' '*kkc*' '*m17n*' '*hangul*' '*anthy*' words

#Remove codec + image + printers
sudo dnf -y remove openh264 ImageMagick* sane* simple-scan

#Remove Active Directory + Sysadmin + reporting tools
sudo dnf -y remove 'sssd*' realmd adcli cyrus-sasl-plain cyrus-sasl-gssapi mlocate quota* dos2unix kpartx sos abrt samba-client gvfs-smb

#Remove vm and virtual stuff
sudo dnf -y remove 'podman*' '*libvirt*' 'open-vm*' qemu-guest-agent 'hyperv*' spice-vdagent virtualbox-guest-additions vino xorg-x11-drv-vmware xorg-x11-drv-amdgpu

#Remove NetworkManager
sudo dnf -y remove NetworkManager-pptp-gnome NetworkManager-ssh-gnome NetworkManager-openconnect-gnome NetworkManager-openvpn-gnome NetworkManager-vpnc-gnome ppp* ModemManager

#Remove Gnome apps
sudo dnf remove -y gnome-photos gnome-connections gnome-tour gnome-themes-extra gnome-screenshot gnome-remote-desktop gnome-font-viewer gnome-calculator gnome-calendar gnome-contacts \
    gnome-maps gnome-weather gnome-logs gnome-boxes gnome-disk-utility gnome-clocks gnome-color-manager gnome-characters baobab totem \
    gnome-shell-extension-background-logo gnome-shell-extension-apps-menu gnome-shell-extension-launch-new-instance gnome-shell-extension-places-menu gnome-shell-extension-window-list \
    gnome-classic* gnome-user* gnome-text-editor chrome-gnome-shell eog

#Remove apps
sudo dnf remove -y rhythmbox yelp evince libreoffice* cheese file-roller* mediawriter

#Remove other packages
 sudo dnf remove -y lvm2 rng-tools thermald '*perl*' yajl

# Disable openh264 repo
sudo dnf config-manager --set-disabled fedora-cisco-openh264

# Install packages that I use
sudo dnf -y install gnome-console git-core gnome-shell-extension-appindicator gnome-shell-extension-blur-my-shell gnome-shell-extension-background-logo gnome-shell-extension-dash-to-dock gnome-shell-extension-no-overview

# Install Microsoft Edge if x86_64
MACHINE_TYPE=$(uname -m)
if [ "${MACHINE_TYPE}" == 'x86_64' ]; then
    output 'x86_64 machine, installing Microsoft Edge.'
    curl -O https://packages.microsoft.com/keys/microsoft.asc
    sudo rpm --import microsoft.asc
    rm microsoft.asc
    sudo dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/edge
    sudo dnf install -y microsoft-edge-stable
    sudo mkdir -p /etc/opt/edge/policies/managed/ /etc/opt/edge/policies/recommended/
    sudo chmod 755 /etc/opt/edge/policies/managed/ /etc/opt/edge/policies/recommended/
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/managed.json | sudo tee /etc/opt/edge/policies/managed/managed.json
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Microsoft-Edge-Policies/main/Linux/recommended.json | sudo tee /etc/opt/edge/policies/managed/recommended.json
    sudo chmod 644 /etc/opt/edge/policies/managed/managed.json /etc/opt/edge/policies/managed/recommended.json
fi

# Enable auto TRIM
sudo systemctl enable fstrim.timer

# Setup fwupd
echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
sudo systemctl restart fwupd

### Differentiating bare metal and virtual installs

# Installing tuned first here because virt-what is 1 of its dependencies anyways
sudo dnf install tuned -y

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
  sudo dnf remove tuned -y
else
  sudo tuned-adm profile virtual-guest
fi

# Setup real-ucode
if [ "$virt_type" = '' ]; then
    sudo dnf install 'https://divested.dev/rpm/fedora/divested-release-20230406-2.noarch.rpm'
    sudo sed -i 's/^metalink=.*/&?protocol=https/g' /etc/yum.repos.d/divested-release.repo
    sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware
    sudo dnf install real-ucode
    sudo dracut -f
fi

output 'The script is done. You can also remove gnome-terminal since gnome-console will replace it.'
