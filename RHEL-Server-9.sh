#!/bin/bash
#Assuming that you are using ANSSI-BP-028

mkdir -p /etc/ssh/ssh_config.d /etc/ssh/sshd_config.d
echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
echo 'X11Forwarding no
GSSAPIAuthentication no
PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/10-custom.conf
sudo systemctl restart sshd

sudo dnf install tuned unbound yara -y
sudo tuned-adm profile virtual-guest

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
  forward-addr: 8.8.8.8#dns.google
  forward-addr: 8.8.4.4#dns.google
  forward-addr: 2001:4860:4860::8888#dns.google
  forward-addr: 2001:4860:4860::8844#dns.google' | sudo tee /etc/unbound/unbound.conf

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

sudo mkdir -p /etc/systemd/system/sshd.service.d
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf
sudo systemctl restart sshd

sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony.conf
sudo systemctl restart chronyd

sudo insights-client --collector malware-detection
sudo sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml

sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
sudo sed -i 's/net.ipv4.icmp_echo_ignore_all=1/net.ipv4.icmp_echo_ignore_all=0/g' /etc/sysctl.d/30_security-misc.conf
sudo sed -i 's/net.ipv6.icmp.echo_ignore_all=1/net.ipv6.icmp.echo_ignore_all=0/g' /etc/sysctl.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc_kexec-disable.conf -o /etc/sysctl.d/30_security-misc_kexec-disable.conf
sudo sysctl -p

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

sudo mkdir -p /etc/systemd/system/irqbalance.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart irqbalance

sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --reload

sudo sed -i 's/apply_updates = no/apply_updates = yes\nreboot = when-needed/g' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer
