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
