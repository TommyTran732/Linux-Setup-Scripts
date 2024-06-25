#!/bin/bash

# Copyright (C) 2024 Thien Tran
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

# Assumes that it is run AFTER https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/Ubuntu-24.04-Server.sh

output(){
    echo -e '\e[36m'"$1"'\e[0m';
}

unpriv(){
    sudo -u nobody "$@"
}

# Open ports
sudo ufw allow 80/tcp
sudo ufw allow 443

# Add mainline NGINX repo
# This is extremely important as Ubuntu keeps shipping outdated NGINX
sudo curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo chmod 644 /usr/share/keyrings/nginx-archive-keyring.gpg
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/nginx.sources | sudo tee /etc/apt/sources.list.d/nginx.sources
chmod 644 /etc/apt/sources.list.d/nginx.sources

# Add the PHP PPA (Ubuntu repos do not have the latest version, and do not handle pinning properly)
sudo add-apt-repository -y ppa:ondrej/php

# Add upstream MariaDB repo
curl https://supplychain.mariadb.com/mariadb-keyring-2019.gpg | sudo tee /usr/share/keyrings/mariadb-keyring-2019.gpg
chmod 644 /usr/share/keyrings/mariadb-keyring-2019.gpg
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/mariadb.sources | sudo tee /etc/apt/sources.list.d/mariadb.sources
chmod 644 /etc/apt/sources.list.d/nginx.sources

# Update the VM again
sudo apt update
sudo apt full-upgrade -y

# Install the packages
sudo apt install -y nginx mariadb-server mariadb-client php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd php8.3-mbstring php8.3-mysql php8.3-opcache php8.3-readline php8.3-sqlite3 php8.3-xml php8.3-zip php8.3-apcu

# Install certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot