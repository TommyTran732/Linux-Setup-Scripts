# Linux Setup Scripts

[![ShellCheck](https://github.com/TommyTran732/Linux-Setup-Scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/TommyTran732/Linux-Setup-Scripts/actions/workflows/shellcheck.yml)

My setup scripts for my workstations. You should edit the scripts to your liking before running them.
Please run the scripts as your actual user and not root. Provide sudo password when it asks you to. Flatpak packages and themes/icons are only installed for your user and not system wide. <br />

The printing stack (cups) is removed as I do not use it.

Visit my Matrix group: https://invite.arcticfoxes.net/#/#tommy:arcticfoxes.net

## Notes on DNS handling

For desktop installations, the assumption here is that you will use a VPN of some sort for your privacy. No custom DNS server will be configured, as websites [can detect](https://www.dnsleaktest.com/) that you are using a different DNS server from your VPN provider's server.

For server installations (except Proxmox), Unbound will be configured to handle local DNSSEC validation. The difference in the scripts on how this is set up are because of the following reasons:

- Each distribution needs its own Unbound configuration due to version differences and how each distro packages it.
- If both Unbound and systemd-resolved are preset on the system, whichever one gets used depends entirely on whether systemd-resolved is running and controlling `/etc/resolv.conf` or not. My scripts set Unbound to enabled and systemd-resolved whenever possible.
- If systemd-resolved is not present on the system, NetworkManager will take control of `/etc/resolv.conf`. RHEL does not ship with systemd-resolved, so manual configuration to set NetworkManager to use the local DNS forwarder is needed.

## Notes on io_uring
io_uring is disabled. On Proxmox, use aio=native for drives. You will need to manually edit the config for cdrom. Alternatively, if you do not want to deal with this, comment out the io_uring line in `/etc/sysctl.d/99-server.conf`

# Arch Linux
Check out this repository: https://github.com/tommytran732/Arch-Setup-Script <br />

# Qubes OS

Check out this repository: https://github.com/tommytran732/QubesOS-Scripts <br />

# Fedora CoreOS

Check out this repository: https://github.com/tommytran732/Fedora-CoreOS-Ignition

