#!/bin/sh

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

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

# Compliance and updates
systemctl mask debug-shell.service

## Avoid phased updates
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/apt.conf.d/99sane-upgrades | tee /etc/apt/apt.conf.d/99sane-upgrades > /dev/null

# Setup NTS
curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/refs/heads/main/etc/chrony.conf | tee /etc/chrony/chrony.conf > /dev/null
sed -i 's/leapseclist/#leapseclist/' /etc/chrony/chrony.conf
systemctl restart chronyd

# Harden SSH
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | tee /etc/ssh/sshd_config.d/10-custom.conf > /dev/null
sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config.d/10-custom.conf
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | tee /etc/ssh/ssh_config.d/10-custom.conf > /dev/null
mkdir -p /etc/systemd/system/sshd.service.d/
chmod 755 /etc/systemd/system/sshd.service.d/
curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/refs/heads/main/etc/systemd/system/sshd.service.d/override.conf | tee /etc/systemd/system/sshd.service.d/override.conf > /dev/null
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
apt install -y intel-microcode tuned

### This part assumes that you are using systemd-boot
echo "mitigations=auto,nosmt spectre_v2=on spectre_bhi=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret gather_data_sampling=force reg_file_data_sampling=on random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off $(cat /etc/kernel/cmdline)" > /etc/kernel/cmdline
proxmox-boot-tool refresh
###

# Kernel hardening
curl -s https://raw.githubusercontent.com/secureblue/secureblue/live/files/system/etc/modprobe.d/blacklist.conf | tee /etc/modprobe.d/server-blacklist.conf > /dev/null
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/sysctl.d/99-server.conf | tee /etc/sysctl.d/99-server.conf > /dev/null
sysctl -p

# Rebuild initramfs
update-initramfs -u

# Disable coredump
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | tee /etc/security/limits.d/30-disable-coredump.conf > /dev/null
mkdir -p /etc/systemd/coredump.conf.d
curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/coredump.conf.d/disable.conf | tee /etc/systemd/coredump.conf.d/disable.conf > /dev/null

# Disable Nagging
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

systemctl restart pveproxy.service

# Setup tuned
tuned-adm profile virtual-host

# Enable fstrim.timer
systemctl enable --now fstrim.timer
