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

# You need to add either the non-subscription repo or the testing repo from the Proxmox WebUI after running this script.

# Setup NTS
rm -rf /etc/chrony/chrony.conf
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf
systemctl restart chronyd

# Harden SSH
echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
echo 'PasswordAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no' | sudo tee /etc/ssh/sshd_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
mkdir -p /etc/systemd/system/ssh.service.d
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf -o /etc/systemd/system/ssh.service.d/override.conf
systemctl daemon-reload
systemctl restart sshd

# Setup repositories
sed -i '1 {s/^/#/}' /etc/apt/sources.list.d/pve-enterprise.list

echo 'deb https://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware

deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' | tee /etc/apt/sources.list

echo 'deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription' | tee /etc/apt/sources.list.d/ceph.list

# Update and install packages
apt update
apt upgrade -y
apt install -y --no-install-recommends intel-microcode tuned fwupd dropbear-initramfs

### This part assumes that you are using systemd-boot
echo -e "spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt tsx=off tsx_async_abort=full,nosmt kvm.nx_huge_pages=force nosmt=force l1d_flush=on mmio_stale_data=full,nosmt random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=on efi=disable_early_pci_dma iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on extra_latent_entropy debugfs=off $(cat /etc/kernel/cmdline)" > /etc/kernel/cmdline
proxmox-boot-tool refresh
###

# Kernel hardening
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf -o /etc/sysctl.d/990-security-misc.conf
sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
mkdir -p /etc/systemd/system/NetworkManager.service.d
curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
echo "* hard core 0" | tee -a /etc/security/limits.conf

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