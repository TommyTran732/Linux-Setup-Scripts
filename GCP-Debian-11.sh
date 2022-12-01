#!/bin/bash

find /etc/apt/sources.list.d -type f -exec sed -i 's/http:/https:/g' {} \;

apt update
apt upgrade -y
apt install -y tuned apparmor-profiles ufw

tuned-adm profile virtual-guest

curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
mkdir -p /etc/systemd/system/NetworkManager.service.d
curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
mkdir -p /etc/systemd/system/sshd.service.d
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf

rm -rf /etc/chrony/chrony.conf
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf

echo "* hard core 0" | tee -a /etc/security/limits.conf

sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
