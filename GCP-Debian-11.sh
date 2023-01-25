#!/bin/bash

echo 'GSSAPIAuthentication no
VerifyHostKeyDNS yes' | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

sudo find /etc/apt/sources.list.d -type f -exec sudo sed -i 's/http:/https:/g' {} \;

sudo apt update
sudo apt upgrade -y
sudo apt install -y tuned apparmor-profiles unbound ufw

sudo tuned-adm profile virtual-guest

echo 'server:
  trust-anchor-signaling: yes
  root-key-sentinel: yes

  hide-identity: yes
  hide-trustanchor: yes
  hide-version: yes
  deny-any: yes
  do-not-query-localhost: yes
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
  outgoing-port-avoid: 51820

  prefetch: yes
  prefetch-key: yes


forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: 8.8.8.8#dns.google
  forward-addr: 8.8.4.4#dns.google
  forward-addr: 2001:4860:4860::8888#dns.google
  forward-addr: 2001:4860:4860::8844#dns.google' | sudo tee /etc/unbound/unbound.conf.d/custom.conf

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
ProtectSystem=strict
RuntimeDirectory=unbound
ConfigurationDirectory=unbound
StateDirectory=unbound
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

sudo systemctl restart unbound

sudo mkdir -p /etc/systemd/system/sshd.service.d
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf

sudo rm -rf /etc/chrony/chrony.conf
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf
sudo systemctl restart chronyd

sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf

echo "* hard core 0" | tee -a /etc/security/limits.conf
