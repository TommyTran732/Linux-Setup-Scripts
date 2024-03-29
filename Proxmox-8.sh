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

# You need to add either the non-subscription repo or the testing repo from the Proxmox WebUI after running this script.

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

# Compliance and updates
systemctl mask debug-shell.service

## Avoid phased updates
curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/apt.conf.d/99sane-upgrades | tee /etc/apt/apt.conf.d/99sane-upgrades
chmod 644 /etc/apt/apt.conf.d/99sane-upgrades

# Setup NTS
rm -rf /etc/chrony/chrony.conf
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | tee /etc/chrony/chrony.conf
systemctl restart chronyd

# Harden SSH
curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | tee /etc/ssh/sshd_config.d/10-custom.conf
chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | tee /etc/ssh/ssh_config.d/10-custom.conf
chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
mkdir -p /etc/systemd/system/ssh.service.d
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | tee /etc/systemd/system/ssh.service.d/override.conf
systemctl daemon-reload
systemctl restart sshd

# Setup repositories
sed -i '1 {s/^/# /}' /etc/apt/sources.list.d/pve-enterprise.list
sed -i '1 {s/^/# /}' /etc/apt/sources.list.d/ceph.list

echo 'deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

deb https://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware

deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' | tee /etc/apt/sources.list

echo 'deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription' | tee -a /etc/apt/sources.list.d/ceph.list


# Update packages
apt update
apt full-upgrade -y
apt autoremove -y

# Install packages
apt install -y intel-microcode tuned fwupd dropbear-initramfs

### This part assumes that you are using systemd-boot
echo -e "mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off $(cat /etc/kernel/cmdline)" > /etc/kernel/cmdline
proxmox-boot-tool refresh
###

# Kernel hardening
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sed -i 's/# install bluetooth/install bluetooth/g' /etc/modprobe.d/30_security-misc.conf
sed -i 's/# install btusb/install btusb/g' /etc/modprobe.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf -o /etc/sysctl.d/990-security-misc.conf
sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
sysctl -p

# Rebuild initramfs
update-initramfs -u

# Disable coredump
curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf

# Harden SSH
sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/g' /etc/ssh/sshd_config

# Setup automatic updates

mkdir -p /etc/systemd/system/pve-daily-update.service.d
echo '[Service]
ExecStart=/usr/bin/pveupgrade' | tee /etc/systemd/system/pve-daily-update.service.d/override.conf
systemctl daemon-reload
systemctl enable --now pve-daily-update.timer

mkdir -p /etc/systemd/system/fwupd-refresh.service.d
echo '[Service]
ExecStart=/usr/bin/fwupdmgr update' | tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
systemctl daemon-reload
systemctl enable --now fwupd-refresh.timer

# Disable Nagging
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

systemctl restart pveproxy.service

# Setup tuned
tuned-adm profile virtual-host

# Enable fstrim.timer
systemctl enable --now fstrim.timer