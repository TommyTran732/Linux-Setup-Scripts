# Linux Setup Scripts
My setup scripts for my workstations. You should edit the scripts to your liking before running it. 
Please run the scripts as your actual user and not root. Provide sudo password when it asks you to. Flatpak packages and themes/icons are only installed for your user and not system wide. <br />

Do note that I remove bluetooth (bluez and gnome-bluetooth) from the system, as well as the printing stack (cups, printer-drivers, etc) as I do not use them. 

Visit my Matrix group: https://matrix.to/#/#tommytran732:matrix.org

# Arch Linux
Check out this repository: https://github.com/tommytran732/Arch-Setup-Script <br />

# Fedora Workstation 33

1. Debloat Fedora <br />
The script removes some ~800 useless packages from the default installation. A lot of these have Flatpak alternatives and you should be using them for app confinement. <br />

2. Setup basic privacy and security (Setting umask to 077, closing open ports on firewalld, randomizing mac address, disabling ptrace, install openSnitch as an outbound firewall, ...) <br />
3. Setup a BTRFS layout compatible with Timeshift. Credits to https://mutschler.eu/linux/install-guides/fedora-btrfs/ <br />
4. Install proprietary Nvidia Drivers and sign them (yes, you don't have to sacrifice Secure Boot for these proprietary drivers. The drivers will be automatically built and signed every kernel update as well. It was honestly a headache to get it working, and it seems to only work on Workstation... I don't know how to get it to work on Silverblue yet.) <br >
5. ~~Setup Anbox using the snap package and out of tree kernel modules (yes, the kernel modules are automatically signed by DKMS - this was also a pain. If only Fedora included the in tree ashmem and binder modules in their kernel. I also provide some selinux policies for ya as well, don't be an idiot and set it to permissive mode!)~~ Broken since Fedora 33 updated to kernel 5.11. <br >
6. Setup Flathub <br >
7. Quality of life stuff (Installing some packages that I use, enabling autotrim, setting up a nice GNOME, GTK, and icon theme, speeding up DNF, ...) <br />
8. Fix broken audio with Steam

![image](https://user-images.githubusercontent.com/57488583/111019751-29378b00-838f-11eb-8f8f-1f5d374c377e.png) <br />
<br />
![image](https://user-images.githubusercontent.com/57488583/111032096-af2bf400-83d8-11eb-9bcb-da0e3ec278d6.png) <br />

# Ubuntu Desktop 20.04 LTS 

Similar to the Fedora script, this script <br >

1. Debloat Ubuntu <br />
The script removes some ~200 useless packages from the minimal installation.  

2. Setup basic privacy and security (Setting umask to 077, enabling ufw, randomizing mac address, disabling ptrace, install openSnitch as an outbound firewall, removing unnecessary permissions...) <br />

3. Install and set AppArmor profiles to enforcing mode

4. Replace the Snap Store with GNOME Software + Snap and Flatpak plugins

5. Quality of life stuff (Installing some packages that I use, enabling autotrim, setting up a nice GNOME, GTK, and icon theme, ...) <br />

6. Remove telemetry (apports, popularity contest, whoopsie) - Keep in mind Snapd still phones home with your unique ID and installed snap packages list. Remove snapd if you don't need it. <br />

7. Signing Ashmem kernel modules (for whatever reason, it is not signed by default)

I would recommend that you follow this guide and setup Encrypted ZFS instead of BTRFS with Timeshift on Ubuntu: https://linsomniac.gitlab.io/post/2020-04-09-ubuntu-2004-encrypted-zfs/

![image](https://user-images.githubusercontent.com/57488583/113504635-e0f03080-9528-11eb-8ce4-faeda3520e8c.png)

