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

#Please note that this is how I PERSONALLY setup my computer - I do some stuff such as not using anything to download GNOME extensions from extensions.gnome.org and installing the extensions as a package instead

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
    sudo -u nobody "$@"
}

virtualization=$(systemd-detect-virt)

# Increase compression level
sudo sed -i 's/zstd:1/zstd:3/g' /etc/fstab

# Compliance
sudo systemctl mask debug-shell.service
sudo systemctl mask kdump.service

# Setting umask to 077
umask 077
sudo sed -i 's/^UMASK.*/UMASK 077/g' /etc/login.defs
sudo sed -i 's/^HOME_MODE/#HOME_MODE/g' /etc/login.defs
sudo sed -i 's/^USERGROUPS_ENAB.*/USERGROUPS_ENAB no/g' /etc/login.defs
sudo sed -i 's/umask 022/umask 077/g' /etc/bashrc

# Make home directory private
sudo chmod 700 /home/*

# Setup NTS
sudo rm -rf /etc/chrony.conf
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/chrony.conf | sudo tee /etc/chrony.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/sysconfig/chronyd | sudo tee /etc/sysconfig/chronyd

sudo systemctl restart chronyd

# Remove nullok
sudo /usr/bin/sed -i 's/\s+nullok//g' /etc/pam.d/system-auth

# Harden SSH
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/ssh_config.d/10-custom.conf | sudo tee /etc/ssh/ssh_config.d/10-custom.conf
sudo chmod 644 /etc/ssh/ssh_config.d/10-custom.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/ssh/sshd_config.d/10-custom.conf | sudo tee /etc/ssh/sshd_config.d/10-custom.conf
sudo mkdir -p /etc/systemd/system/sshd.service.d/
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/sshd.service.d/local.conf | sudo tee /etc/systemd/system/sshd.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl restart sshd

# Security kernel settings
unpriv curl https://raw.githubusercontent.com/Kicksecure/security-misc/master/etc/modprobe.d/30_security-misc.conf | sudo tee /etc/modprobe.d/30_security-misc.conf
sudo chmod 644 /etc/modprobe.d/30_security-misc.conf
sudo sed -i 's/#install msr/install msr/g' /etc/modprobe.d/30_security-misc.conf
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
sudo dracut -f
sudo sysctl -p

if [ -d /usr/lib/systemd/boot/efi ]; then
    sudo sed -i 's/quiet root/quiet mitigations=auto,nosmt spectre_v2=on spectre_bhi=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret gather_data_sampling=force reg_file_data_sampling=on random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off lockdown=confidentiality module.sig_enforce=1 console=tty0 console=ttyS0,115200 root/g' /etc/kernel/cmdline
    sudo dnf reinstall -y kernel-core
else
    sudo grubby --update-kernel=ALL --args='mitigations=auto,nosmt spectre_v2=on spectre_bhi=on spec_store_bypass_disable=on tsx=off kvm.nx_huge_pages=force nosmt=force l1d_flush=on spec_rstack_overflow=safe-ret gather_data_sampling=force reg_file_data_sampling=on random.trust_bootloader=off random.trust_cpu=off intel_iommu=on amd_iommu=force_isolation efi=disable_early_pci_dma iommu=force iommu.passthrough=0 iommu.strict=1 slab_nomerge init_on_alloc=1 init_on_free=1 pti=on vsyscall=none ia32_emulation=0 page_alloc.shuffle=1 randomize_kstack_offset=on debugfs=off lockdown=confidentiality module.sig_enforce=1 console=tty0 console=ttyS0,115200'
fi

# Disable coredump
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/security/limits.d/30-disable-coredump.conf | sudo tee /etc/security/limits.d/30-disable-coredump.conf

# Setup ZRAM
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/zram-generator.conf | sudo tee /etc/systemd/zram-generator.conf

# Setup DNF
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/dnf/dnf.conf | sudo tee /etc/dnf/dnf.conf
sudo sed -i 's/^metalink=.*/&\&protocol=https/g' /etc/yum.repos.d/*

# Setup automatic updates
sudo dnf install -y dnf-automatic
sudo sed -i 's/apply_updates = no/apply_updates = yes\nreboot = when-needed/g' /etc/dnf/automatic.conf
sudo systemctl enable --now dnf-automatic.timer

# Remove unnecessary packages
sudo dnf remove -y cockpit*

# Install appropriate virtualization drivers
if [ "$virtualization" = 'kvm' ]; then
    sudo dnf install -y qemu-guest-agent
fi

# Setup unbound
sudo dnf install unbound -y
unpriv curl https://raw.githubusercontent.com/TommyTran732/Fedora-CoreOS-Ignition/main/etc/unbound/unbound.conf | sudo tee /etc/unbound/unbound.conf
sudo mkdir /etc/systemd/system/unbound.service.d
unpriv curl https://raw.githubusercontent.com/TommyTran732/Fedora-CoreOS-Ignition/main/etc/systemd/system/unbound.service.d/override.conf | sudo tee /etc/systemd/system/unbound.service.d/override.conf
sudo systemctl enable --now unbound
sudo systemctl disable systemd-resolved

# Setup fwupd
if [ "$virtualization" = 'none' ]; then
    sudo dnf install -y fwupd
    echo 'UriSchemes=file;https' | sudo tee -a /etc/fwupd/fwupd.conf
    sudo systemctl restart fwupd
    mkdir -p /etc/systemd/system/fwupd-refresh.service.d
    unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/systemd/system/fwupd-refresh.service.d/override.conf | sudo tee /etc/systemd/system/fwupd-refresh.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable --now fwupd-refresh.timer
fi

# Enable auto TRIM
sudo systemctl enable fstrim.timer

### Differentiating bare metal and virtual installs

# Setup tuned
sudo dnf install -y tuned
sudo systemctl enable --now tuned

if [ "$virtualization" = 'none' ]; then
    sudo tuned-adm profile latency-performance
else
    sudo tuned-adm profile virtual-guest
fi


# Setup real-ucode and hardened_malloc
MACHINE_TYPE=$(uname -m)
if [ "$virtualization" = 'none' ] || [ "${MACHINE_TYPE}" == 'x86_64' ]; then
    sudo dnf install -y 'https://divested.dev/rpm/fedora/divested-release-20231210-2.noarch.rpm'
    sudo sed -i 's/^metalink=.*/&?protocol=https/g' /etc/yum.repos.d/divested-release.repo
    if [ "${MACHINE_TYPE}" != 'x86_64' ]; then
        sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware
        sudo dnf install -y real-ucode
        sudo dracut -f
    elif [ "$virtualization" != 'none' ]; then
        sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,hardened_malloc
        sudo dnf install -y hardened_malloc
    else
        sudo dnf config-manager --save --setopt=divested.includepkgs=divested-release,real-ucode,microcode_ctl,amd-ucode-firmware,hardened_malloc
        sudo dnf install -y real-ucode hardened_malloc
        echo 'libhardened_malloc.so' | sudo tee /etc/ld.so.preload
        sudo dracut -f
    fi
elif [ "${MACHINE_TYPE}" == 'aarch64' ]; then
    sudo dnf copr enable secureblue/hardened_malloc -y
    sudo dnf install -y hardened_malloc
fi

# Setup networking
sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --reload
sudo firewall-cmd --lockdown-on

sudo mkdir -p /etc/systemd/system/NetworkManager.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/NetworkManager.service.d/99-brace.conf | sudo tee /etc/systemd/system/NetworkManager.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart NetworkManager

# irqbalance hardening
sudo mkdir -p /etc/systemd/system/irqbalance.service.d
unpriv curl https://gitlab.com/divested/brace/-/raw/master/brace/usr/lib/systemd/system/irqbalance.service.d/99-brace.conf | sudo tee /etc/systemd/system/irqbalance.service.d/99-brace.conf
sudo systemctl daemon-reload
sudo systemctl restart irqbalance

# Setup notices
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/issue | sudo tee /etc/issue
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/issue | sudo tee /etc/issue.net