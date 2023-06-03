#!/bin/bash

#Run this as your user to set the theme

#Enable Titlebar buttons
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

#Setting Legacy GTK theme
gsettings set org.gnome.desktop.interface gtk-theme "Flat-Remix-GTK-Blue-Dark-Solid"
flatpak upgrade -y

#Setting icons
git clone https://github.com/horst3180/arc-icon-theme.git
mkdir /home/"${USER}"/.icons
ln -s /home/"${USER}"/arc-icon-theme/Arc /home/"${USER}"/.icons/
git clone https://github.com/tommytran732/Mojave-CT.git
ln -s /home/"${USER}"/Mojave-CT /home/"${USER}"/.icons/
sed -i 's/Inherits=Moka,Adwaita,gnome,hicolor/Inherits=Mojave-CT,Moka,Adwaita,gnome,hicolor/g' /home/"${USER}"/arc-icon-theme/Arc/index.theme
find /home/"${USER}"/arc-icon-theme -name '*[Tt]rash*' -exec rm {} \;
gsettings set org.gnome.desktop.interface icon-theme "Arc"
