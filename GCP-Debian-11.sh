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

output(){
  echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
  sudo -u nobody "$@"
}

# Compliance and updates
sudo systemctl mask debug-shell.service

## Avoid phased updates
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/apt.conf.d/99sane-upgrades | sudo tee /etc/apt/apt.conf.d/99sane-upgrades
sudo chmod 644 /etc/apt/apt.conf.d/99sane-upgrades

sudo apt update
sudo apt full-upgrade -y
sudo apt autoremove -y

# Make home directory private
sudo chmod 700 /home/*

# Setup NTS
sudo rm -rf /etc/chrony/chrony.conf
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony/chrony.conf
sudo systemctl restart chronyd

# Setup repositories
sudo find /etc/apt/sources.list.d -type f -exec sudo sed -i 's/http:/https:/g' {} \;

# Setup ufw
sudo apt install ufw -y
sudo ufw enable
sudo ufw allow OpenSSH

# Harden SSH
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | sudo tee /etc/ssh/sshd_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
sudo mkdir -p /etc/systemd/system/ssh.service.d
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | sudo tee /etc/systemd/system/ssh.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Kernel Hardening

unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
sudo chmod 644 /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/# install bluetooth/install bluetooth/g' /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/# install btusb/install btusb/g' /etc/modprobe.d/30_security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf | sudo tee /etc/sysctl.d/990-security-misc.conf
sudo chmod 644 /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf | sudo tee /etc/sysctl.d/30_silent-kernel-printk.conf
sudo chmod 644 /etc/sysctl.d/30_silent-kernel-printk.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf | sudo tee /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo chmod 644 /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sysctl -p

# Rebuild initramfs
sudo update-initramfs -u

# Disable coredump
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf

# System Hardening
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf

# Update GRUB config
# shellcheck disable=SC2016
echo 'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off"' | sudo tee -a /etc/grub.d/40_custom
sudo update-grub

# Setup tuned
sudo dnf install tuned -y
sudo tuned-adm profile virtual-guest

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer

### Differentiating bare metal and virtual installs

# Installing tuned first here because virt-what is 1 of its dependencies anyways
sudo apt install tuned -y

virt_type=$(virt-what)
if [ "$virt_type" = "" ]; then
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
if [ "$virt_type" = "" ]; then
  sudo tuned-adm profile latency-performance
else
  sudo tuned-adm profile virtual-guest
fi

# Setup fwupd
if [ "$virt_type" = '' ]; then
  sudo apt install fwupd -y
  echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
  sudo systemctl restart fwupd
  mkdir -p /etc/systemd/system/fwupd-refresh.service.d
  unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl enable --now fwupd-refresh.timer
fi

# Setup unbound
sudo apt instal unbound resolvconf -y

echo 'server:
  trust-anchor-signaling: yes
  root-key-sentinel: yes
  tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt

  hide-identity: yes
  hide-trustanchor: yes
  hide-version: yes
  deny-any: yes
  harden-algo-downgrade: yes
  harden-large-queries: yes
  harden-referral-path: yes
  ignore-cd-flag: yes
  max-udp-size: 3072
  module-config: "validator iterator"
  qname-minimisation-strict: yes
  unwanted-reply-threshold: 10000000
  use-caps-for-id: yes

  outgoing-port-permit: 1024-65535

  prefetch: yes
  prefetch-key: yes


forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 1.1.1.2@853#security.cloudflare-dns.com
  forward-addr: 1.0.0.2@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1112@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf.d/custom.conf

mkdir -p /etc/systemd/system/unbound.service.d
echo $'[Service]
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETGID CAP_SETUID CAP_SYS_CHROOT CAP_SYS_RESOURCE CAP_NET_RAW
MemoryDenyWriteExecute=true
NoNewPrivileges=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
# This breaks using socket options like \'so-rcvbuf\'. Explicitly disable for visibility.
ProtectKernelTunables=false
ProtectProc=invisible
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
RestrictRealtime=true
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug @keyring @module mount @obsolete @resources
RestrictNamespaces=yes
LockPersonality=yes
RestrictSUIDSGID=yes
ReadWritePaths=@UNBOUND_RUN_DIR@ @UNBOUND_CHROOT_DIR@

# Below rules are needed when chroot is enabled (usually it\'s enabled by default).
# If chroot is disabled like chroot: "" then they may be safely removed.
TemporaryFileSystem=@UNBOUND_CHROOT_DIR@/dev:ro
TemporaryFileSystem=@UNBOUND_CHROOT_DIR@/run:ro
BindReadOnlyPaths=-/run/systemd/notify:@UNBOUND_CHROOT_DIR@/run/systemd/notify
BindReadOnlyPaths=-/dev/urandom:@UNBOUND_CHROOT_DIR@/dev/urandom
BindPaths=-/dev/log:@UNBOUND_CHROOT_DIR@/dev/log' | sudo tee /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl daemon-reload
sudo systemctl restart unbound
sudo systemctl disable systemd-resolved
sudo reboot