# Linux Setup Scripts
My setup scripts for my workstations. You should edit the scripts to your liking before running it.
Please run the scripts as your actual user and not root. Provide sudo password when it asks you to. Flatpak packages and themes/icons are only installed for your user and not system wide. <br />

Do note that I remove bluetooth (bluez and gnome-bluetooth) from the system, as well as the printing stack (cups, printer-drivers, etc) as I do not use them.

Visit my Matrix group: https://matrix.to/#/#tommytran732:matrix.org

# Fedora Workstation 38

1. Debloat Fedora <br />
The script removes some ~800 useless packages from the default installation. A lot of these have Flatpak alternatives. <br />
2. Setup basic privacy and security (Setting umask to 077, closing open ports on firewalld, randomizing mac address, kernel module blacklist, sysctl hardening, etc) <br />
3. Setup a BTRFS layout compatible with Timeshift. Credits to https://mutschler.dev/linux/fedora-btrfs-33/ <br />
4. Setup Flathub <br >
5. Quality of life stuff (Installing some packages that I use, enabling autotrim, setting up a nice GNOME, GTK, and icon theme, speeding up DNF, ...) <br />

# Proxmox 7 & Debian 11

Setup basic privacy and security (installing apparmor profiles kernel module blacklist, sysctl hardening, etc) <br />

# Arch Linux
Check out this repository: https://github.com/tommytran732/Arch-Setup-Script <br />

# Qubes OS

Checkout this repository: https://github.com/tommytran732/QubesOS-Scripts <br />

# Fedora CoreOS

Checkout this repository: https://github.com/tommytran732/Fedora-CoreOS-Ignition
