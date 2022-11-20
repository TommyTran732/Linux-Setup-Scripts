#!/bin/bash

sed -i '1 {s/^/#/}' /etc/apt/sources.list.d/pve-enterprise.list
sed -i 's/main contrib/main contrib non-free/' /etc/apt/sources.list
apt update
apt upgrade -y
apt install -y intel-microcode tuned apparmor-profiles fwupd

tuned-adm profile virtual-host

### This part assumes that you are using systemd-boot
echo -e "spectre_v2=on spec_store_bypass_disable=on l1tf=full,force mds=full,nosmt tsx=off tsx_async_abort=full,nosmt kvm.nx_huge_pages=force nosmt=force l1d_flush=on mmio_stale_data=full,nosmt random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=on efi=disable_early_pci_dma iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none page_alloc.shuffle=1 randomize_kstack_offset=on extra_latent_entropy debugfs=off $(cat /etc/kernel/cmdline)" > /etc/kernel/cmdline
proxmox-boot-tool refresh
###

curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf -o /etc/modprobe.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_security-misc.conf -o /etc/sysctl.d/30_security-misc.conf
curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf -o /etc/sysctl.d/30_silent-kernel-printk.conf
sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf

rm -rf /etc/chrony/chrony.conf
curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf -o /etc/chrony/chrony.conf

echo "* hard core 0" | tee -a /etc/security/limits.conf

sed -i 's/#GSSAPIAuthentication no/GSSAPIAuthentication no/g' /etc/ssh/sshd_config

mkdir -p /etc/systemd/system/pve-daily-update.service.d
echo '[Service]
ExecStart=/usr/bin/pveupgrade' | tee /etc/systemd/system/pve-daily-update.service.d/override.conf
systemctl daemon-reload
systemctl enable --now pve-daily-update.timer

mkdir -p /etc/systemd/system/pve-daily-update.service.d
echo '[Service]
ExecStart=ExecStart=/usr/bin/fwupdmgr update' | tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
systemctl daemon-reload
systemctl enable --now fwupd-refresh.timer

bash <(curl -s https://raw.githubusercontent.com/Weilbyte/PVEDiscordDark/master/PVEDiscordDark.sh ) install
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
