# Fedora-Workstation-Setup
My setup script for Fedora Workstation edition. You should edit the script to your liking before running it. <br />
The script is tested on Fedora Workstation 33. <br />
Please run the script as your actual user and not root. Provide sudo password when it asks you to. Flatpak packages and themes/icons are only installed for your user and not system wide. <br />


# Notable Features

1. Debloat Fedora <br />
It removes some ~800 useless packages from the default installation. A lot of these have Flatpak alternatives and you should be using them for app confinement. <br />

2. Setup basic privacy and security (Setting umask to 077, closing open ports on firewalld, randomizing mac address, disabling ptrace, install openSnitch as an outbound firewall, ...) <br />
3. Setup a BTRFS layout compatible with Timeshift. Credits to https://mutschler.eu/linux/install-guides/fedora-btrfs/ <br />
4. Install proprietary Nvidia Drivers and sign them (yes, you don't have to sacrifice Secure Boot for these proprietary drivers. The drivers will be automatically built and signed every kernel update as well. It was honestly a headache to get it working, and it seems to only work on Workstation... I don't know how to get it to work on Silverblue yet.) <br >
5. Setup Anbox uing the snap package and out of tree kernel modules (yes, the kernel modules are automatically signed by DKMS as well - this is also a pain. If only Fedora included the in tree ashmem and binder modules in their kernel)
6. Setup Flathub <br >
7. Quality of life stuff (Installing some packages that I use, enabling autotrim, setting up a nice GNOME, GTK, and icon theme, speeding up DNF, ...) <br />
8. Fix broken audio with Steam

![image](https://user-images.githubusercontent.com/57488583/111019751-29378b00-838f-11eb-8f8f-1f5d374c377e.png) <br />
