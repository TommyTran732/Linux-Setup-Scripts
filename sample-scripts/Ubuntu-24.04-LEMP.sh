#!/bin/sh

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

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

# Open ports
sudo ufw allow 80/tcp
sudo ufw allow 443

# Add mainline NGINX repo
# This is extremely important as Ubuntu keeps shipping outdated NGINX
unpriv curl -s https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo chmod 644 /usr/share/keyrings/nginx-archive-keyring.gpg
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/nginx.sources | sudo tee /etc/apt/sources.list.d/nginx.sources > /dev/null
sudo chmod 644 /etc/apt/sources.list.d/nginx.sources

# Add the PHP PPA (Ubuntu repos do not have the latest version, and do not handle pinning properly)
sudo add-apt-repository -y ppa:ondrej/php

# Add upstream MariaDB repo
unpriv curl -s https://supplychain.mariadb.com/mariadb-keyring-2019.gpg | sudo tee /usr/share/keyrings/mariadb-keyring-2019.gpg
sudo chmod 644 /usr/share/keyrings/mariadb-keyring-2019.gpg
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/mariadb.sources | sudo tee /etc/apt/sources.list.d/mariadb.sources > /dev/null
sudo chmod 644 /etc/apt/sources.list.d/maridadb.sources

# Update the VM again
sudo apt update
sudo apt full-upgrade -y

# Install the packages
sudo apt install -y nginx mariadb-server php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd php8.3-mbstring php8.3-mysql php8.3-opcache php8.3-readline php8.3-sqlite3 php8.3-xml php8.3-zip php8.3-apcu

# Install certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Secure MariaDB
output "Running mariadb-secure-installation." 
output "You should answer yes to everything except setting the root password."
output "This is already done via the UNIX socket if you switch it with the prompts so you should be okay."
sudo mariadb-secure-installation

# Port NGINX configs from https://github.com/TommyTran732/NGINX-Configs

sudo rm -rf /etc/nginx/conf.d/default.conf

## NGINX hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx.service.d/local.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/nginx.service.d/override.conf
sudo systemctl daemon-reload

## Setup nginx-create-session-ticket-keys
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-create-session-ticket-keys | sudo tee /usr/local/bin/nginx-create-session-ticket-keys > /dev/null
sudo chmod u+x /usr/local/bin/nginx-create-session-ticket-keys 

## Setup nginx-rotate-session-ticket-keys
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-rotate-session-ticket-keys | sudo tee /usr/local/bin/nginx-rotate-session-ticket-keys > /dev/null
sudo chmod u+x /usr/local/bin/nginx-rotate-session-ticket-keys

## Download the units
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-create-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-create-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.timer | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.timer > /dev/null

## Systemd Hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/systemd/system/nginx.service.d/override.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/nginx.service.d/override.conf
sudo systemctl daemon-reload

## Enable the units
sudo systemctl enable --now nginx-create-session-ticket-keys.service
sudo systemctl enable --now nginx-rotate-session-ticket-keys.timer

## Download NGINX configs

unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/http2.conf | sudo tee /etc/nginx/conf.d/http2.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/sites_default.conf | sudo tee /etc/nginx/conf.d/sites_default.conf > /dev/null
sudo sed -i 's/include snippets/universal_paths.conf;//g' /etc/nginx/conf.d/sites_default.conf
sudo sed -i 's/ipv4_1://g' /etc/nginx/conf.d/sites_default.conf
sudo sed -i 's/ipv6_1/::/g' /etc/nginx/conf.d/sites_default.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/tls.conf | sudo tee /etc/nginx/conf.d/tls.conf > /dev/null

sudo mkdir -p /etc/nginx/snippets
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/hsts.conf | sudo tee /etc/nginx/snippets/hsts.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/proxy.conf | sudo tee /etc/nginx/snippets/proxy.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/quic.conf | sudo tee /etc/nginx/snippets/quic.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/security.conf | sudo tee /etc/nginx/snippets/security.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/cross-origin-security.conf | sudo tee /etc/nginx/snippets/cross-origin-security.conf > /dev/null

# Fix PHP permission
sudo sed -i 's/www-data/nginx/g' /etc/php/8.3/fpm/pool.d/www.conf
sudo systemctl restart php8.3-fpm