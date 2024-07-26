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

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

virtualization=$(systemd-detect-virt)

# Compliance
sudo systemctl mask debug-shell.service
sudo systemctl mask kdump.service

# Setting umask to 077
umask 077
sudo sed -i 's/^UMASK.*/UMASK 077/g' /etc/login.defs
sudo sed -i 's/^HOME_MODE/#HOME_MODE/g' /etc/login.defs
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc

# Make home directory private
sudo chmod 700 /home/*

# Setup NTS
sudo dnf install -y chrony
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony.conf > /dev/null
sudo chmod 644 /etc/chrony.conf
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/sysconfig/chronyd | sudo tee /etc/sysconfig/chronyd > /dev/null
sudo chmod 644 /etc/sysconfig/chronyd

sudo systemctl restart chronyd

# Remove nullok
sudo /usr/bin/sed -i 's/\s+nullok//g' /etc/pam.d/system-auth

# Harden SSH
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | sudo tee /etc/ssh/sshd_config.d/10-custom.conf > /dev/null
sudo chmod 644 /etc/ssh/sshd_config.d/10-custom.conf
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf > /dev/null
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
sudo mkdir -p /etc/systemd/system/sshd.service.d/
sudo chmod 755 /etc/systemd/system/sshd.service.d/
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | sudo tee /etc/systemd/system/sshd.service.d/override.conf > /dev/null
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Security kernel settings
unpriv curl -s https://raw.githubusercontent.com/secureblue/secureblue/live/files/system/usr/etc/modprobe.d/blacklist.conf | sudo tee /etc/modprobe.d/server-blacklist.conf > /dev/null
sudo chmod 644 /etc/modprobe.d/server-blacklist.conf
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/sysctl.d/99-server.conf | sudo tee /etc/sysctl.d/99-server.conf > /dev/null
sudo chmod 644 /etc/sysctl.d/99-server.conf
sudo dracut -f
sudo sysctl -p

sudo grubby --update-kernel=ALL --args='mitigations=auto,nosmt spectre_v2=on spectre_bhi=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret gather_data_sampling=force reg_file_data_sampling=on random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off lockdown=confidentiality module.sig_enforce=1 console=tty0 console=ttyS0,115200'

# Disable coredump
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf > /dev/null
sudo chmod 644 /etc/security/limits.d/30-disable-coredump.conf
sudo mkdir -p /etc/systemd/coredump.conf.d
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/coredump.conf.d/disable.conf | sudo tee /etc/systemd/coredump.conf.d/disable.conf > /dev/null
sudo chmod 644 /etc/systemd/coredump.conf.d/disable.conf

# Setup DNF
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dnf/dnf.conf | sudo tee /etc/dnf/dnf.conf > /dev/null
sudo chmod 644 /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Setup automatic updates
sudo dnf install -y dnf-automatic
sudo sed -i 's/apply_updates = no/apply_updates = yes\nreboot = when-needed/g' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer

# Remove unnecessary packages
sudo dnf remove -y cockpit*

# Install hardened_malloc
sudo dnf copr enable secureblue/hardened_malloc -y
sudo dnf install -y hardened_malloc
echo 'libhardened_malloc.so' | sudo tee /etc/ld.so.preload
sudo chmod 644 /etc/ld.so.preload

# Install appropriate virtualization drivers
if [ "$virtualization" = 'kvm' ]; then
    sudo dnf install -y qemu-guest-agent
fi

# Setup unbound
sudo dnf install unbound -y

echo 'server:
  chroot: ""
  auto-trust-anchor-file: "/var/lib/unbound/root.key"
  trust-anchor-signaling: yes
  root-key-sentinel: yes
  tls-cert-bundle: "/etc/ssl/cert.pem"
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

#  ip-transparent: yes
#  interface: 127.0.0.1
#  interface: ::1
#  interface: 242.242.0.1
#  access-control: 242.242.0.0/16 allow

forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 1.1.1.2@853#security.cloudflare-dns.com
  forward-addr: 1.0.0.2@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1112@853#security.cloudflare-dns.com
  forward-addr: 2606:4700:4700::1002@853#security.cloudflare-dns.com' | sudo tee /etc/unbound/unbound.conf

sudo chmod 644 /etc/unbound/unbound.conf

sudo mkdir -p /etc/systemd/system/unbound.service.d
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/system/unbound.service.d/override.conf | sudo tee /etc/systemd/system/unbound.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/unbound.service.d/override.conf

sudo systemctl enable --now unbound

# Setup yara
#sudo dnf install -y yara
#sudo insights-client --collector malware-detection
#sudo sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml

# Enable auto TRIM
sudo systemctl enable fstrim.timer

### Differentiating bare metal and virtual installs

# Setup fwupd
if [ "$virtualization" = 'none' ]; then
    sudo dnf install -y fwupd
    echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
    sudo systemctl restart fwupd
    mkdir -p /etc/systemd/system/fwupd-refresh.service.d
    unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf > /dev/null
    sudo chmod 644 /etc/systemd/system/fwupd-refresh.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable --now fwupd-refresh.timer
fi

# Setup tuned
sudo dnf install -y tuned
sudo systemctl enable --now tuned

if [ "$virtualization" = 'none' ]; then
    sudo tuned-adm profile latency-performance
else
    sudo tuned-adm profile virtual-guest
fi

# Setup networking
sudo systemctl enable --now firewalld
sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --reload
sudo firewall-cmd --lockdown-on

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
unpriv curl -s https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf > /dev/null
sudo chmod 644 /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

# irqbalance hardening
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl -s https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf > /dev/null
sudo chmod 644 /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart irqbalance

# Setup notices
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/issue | sudo tee /etc/issue > /dev/null
sudo chmod 644 /etc/issue
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/issue | sudo tee /etc/issue.net > /dev/null
sudo chmod 644 /etc/issue.net

# Final notes to the user
output 'Server setup complete. To use unbound for DNS, you need to run the following commands:'
output 'nmcli con mod <interface name> ipv4.dns 127.0.0.1'
output 'nmcli con mod <interface name> ipv6.dns ::1'