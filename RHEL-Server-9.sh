#!/bin/bash
#Assuming that you are using ANSSI-BP-028

mkdir -p /etc/ssh/ssh_config.d /etc/ssh/sshd_config.d
echo "GSSAPIAuthentication no" | sudo tee -a /etc/ssh/ssh_config.d/10-custom.conf
echo "X11Forwarding no
GSSAPIAuthentication no" | sudo tee -a /etc/ssh/sshd_config.d/10-custom.conf
echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/40-disable-passwords.conf

sudo dnf install tuned yara -y
sudo tuned-adm profile virtual-guest

sudo insights-client --collector malware-detection
sudo sed -i 's/test_scan: true/test_scan: false/' /etc/insights-client/malware-detection-config.yml

sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
sudo sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
sudo curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sudo sysctl -p

sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony.conf
sudo systemctl restart chronyd

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf -o /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl restart NetworkManager

sudo mkdir -p /etc/systemd/system/irqbalance.service.d
sudo curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf -o /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl restart irqbalance

sudo mkdir -p /etc/systemd/system/sshd.service.d
sudo curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/limits.conf -o /etc/systemd/system/sshd.service.d/limits.conf
sudo systemctl restart sshd
