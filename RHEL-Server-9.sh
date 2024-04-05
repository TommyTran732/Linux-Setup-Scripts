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

# Compliance
sudo systemctl mask debug-shell.service
sudo systemctl mask kdump.service

# Setup NTS
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/sysconfig/chronyd | sudo tee /etc/sysconfig/chronyd

sudo systemctl restart chronyd

# Make home directory private
sudo chmod 700 /home/*

# Setup Firewalld

sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --reload
sudo firewall-cmd --lockdown-on

# Remove nullok
sudo /usr/bin/sed -i 's/\s+nullok//g' /etc/pam.d/system-auth

# Harden SSH
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | sudo tee /etc/ssh/sshd_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | sudo tee /etc/systemd/system/sshd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Kernel hardening

unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/#install msr/install msr/g' /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/# install bluetooth/install bluetooth/g' /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/# install btusb/install btusb/g' /etc/modprobe.d/30_security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/990-security-misc.conf | sudo tee /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
sudo sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/990-security-misc.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_silent-kernel-printk.conf | sudo tee /etc/sysctl.d/30_silent-kernel-printk.conf
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/usr/lib/sysctl.d/30_security-misc_kexec-disable.conf | sudo tee /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo dracut -f
sudo sysctl -p
sudo grubby --update-kernel=ALL --args='mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off'

# Disable coredump
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf

# Systemd Hardening

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart irqbalance

# Remove packages

sudo dnf remove baobab chrome-gnome-shell evince firefox gedit gnome-calculator gnome-characters gnome-font-viewer gnome-screenshot gnome-tour qemu-guest-agent 'sssd*' 'yelp*'

# Setup dnf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dnf/dnf.conf | sudo tee /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Setup unbound

sudo dnf install unbound -y

echo 'server:
  chroot: ""

  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  trust-anchor-signaling: yes
  root-key-sentinel: yes

  tls-ciphers: "PROFILE=SYSTEM"

  hide-http-user-agent: yes
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
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf

mkdir -p /etc/systemd/system/unbound.service.d
echo $'[Service]
MemoryDenyWriteExecute=true
PrivateDevices=true
PrivateTmp=true
ProtectHome=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelLogs=true
ProtectKernelModules=true
# This breaks using socket options like \'so-rcvbuf\'. Explicitly disable for visibility.
ProtectKernelTunables=true
ProtectProc=invisible
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
RestrictRealtime=true
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug @keyring @module mount @obsolete @resources
RestrictNamespaces=yes
LockPersonality=yes' | sudo tee /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl enable --now unbound

# Setup yara
sudo dnf install -y yara
sudo insights-client --collector malware-detection
sudo sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml

# Setup automatic updates

sudo sed -i 's/apply_updates = no/apply_updates = yes\nreboot = when-needed/g' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer

# Enable fstrim.timer
sudo systemctl enable --now fstrim.timer

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
  sudo tuned-adm profile latency-performance
  if [ "$virt_type" = 'kvm' ]; then
    sudo dnf install qemu-guest-agent -y
  fi
else
  sudo tuned-adm profile virtual-guest
fi

# Setup real-ucode and hardened_malloc
if [ "$virt_type" = '' ] || [ "${MACHINE_TYPE}" == 'x86_64' ]; then
  sudo dnf install 'https://divested.dev/rpm/fedora/divested-release-20231210-2.noarch.rpm' -y
  sudo sed -i 's/^metalink=.*/&?protocol=https/g' /etc/yum.repos.d/divested-release.repo
  if [ "${MACHINE_TYPE}" != 'x86_64' ]; then
    sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware
    sudo dnf install real-ucode -y
    sudo dracut -f
  elif [ "$virt_type" != '' ]; then
    sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,hardened_malloc
    sudo dnf install hardened_malloc -y
  else
    sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware,hardened_malloc
    sudo dnf install real-ucode hardened_malloc -y
    echo 'libhardened_malloc.so' | sudo tee /etc/ld.so.preload
    sudo dracut -f
  fi
elif [ "${MACHINE_TYPE}" == 'aarch64' ]; then
  sudo dnf copr enable secureblue/hardened_malloc -y
  sudo dnf install hardened_malloc -y
fi

# Setup fwupd
if [ "$virt_type" = '' ]; then
  sudo dnf install fwupd -y
  echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
  sudo systemctl restart fwupd
  mkdir -p /etc/systemd/system/fwupd-refresh.service.d
  unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl enable --now fwupd-refresh.timer
fi
