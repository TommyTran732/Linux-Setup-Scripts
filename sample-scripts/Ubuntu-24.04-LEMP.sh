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
sudo curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo chmod 644 /usr/share/keyrings/nginx-archive-keyring.gpg
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/nginx.sources | sudo tee /etc/apt/sources.list.d/nginx.sources
sudo chmod 644 /etc/apt/sources.list.d/nginx.sources

# Add the PHP PPA (Ubuntu repos do not have the latest version, and do not handle pinning properly)
sudo add-apt-repository -y ppa:ondrej/php

# Add upstream MariaDB repo
curl https://supplychain.mariadb.com/mariadb-keyring-2019.gpg | sudo tee /usr/share/keyrings/mariadb-keyring-2019.gpg
sudo chmod 644 /usr/share/keyrings/mariadb-keyring-2019.gpg
unpriv curl https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/apt/sources.list.d/mariadb.sources | sudo tee /etc/apt/sources.list.d/mariadb.sources
sudo chmod 644 /etc/apt/sources.list.d/nginx.sources

# Update the VM again
sudo apt update
sudo apt full-upgrade -y

# Install the packages
sudo apt install -y nginx mariadb-server mariadb-client php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-fpm php8.3-gd php8.3-mbstring php8.3-mysql php8.3-opcache php8.3-readline php8.3-sqlite3 php8.3-xml php8.3-zip php8.3-apcu

# Install certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Secure MariaDB
output "Running mariadb-secure-installation. You should answer yes to everything."
sudo mariadb-secure-installation

# Port NGINX configs from https://github.com/TommyTran732/NGINX-Configs

sudo rm -rf /etc/nginx/conf.d/default.conf

## Setup webroot for NGINX
sudo mkdir -p /srv/nginx
sudo mkdir -p /srv/nginx/.well-known/acme-challenge

## NGINX hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx.service.d/local.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf
sudo systemctl daemon-reload

## Setup certbot-ocsp-fetcher
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/certbot-ocsp-fetcher | sudo tee /usr/local/bin/certbot-ocsp-fetcher
sudo mkdir -p /var/cache/certbot-ocsp-fetcher/

## Setup nginx-create-session-ticket-keys
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-create-session-ticket-keys | sudo tee /usr/local/bin/nginx-create-session-ticket-keys

## Setup nginx-rotate-session-ticket-keys
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-rotate-session-ticket-keys | sudo tee /usr/local/bin/nginx-rotate-session-ticket-keys

## Download the units
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/certbot-ocsp-fetcher.service | sudo tee /etc/systemd/system/certbot-ocsp-fetcher.service
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/certbot-ocsp-fetcher.timer | sudo tee /etc/systemd/system/certbot-ocsp-fetcher.timer
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-create-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-create-session-ticket-keys.service
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.service
unpriv curl https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.timer | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.timer

## Systemd Hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/systemd/system/nginx.service.d/override.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf
sudo systemctl daemon-reload

## Enable the units
sudo systemctl enable certbot-ocsp-fetcher.timer
sudo systemctl enable --now nginx-create-session-ticket-keys.service
sudo systemctl enable --now nginx-rotate-session-ticket-keys.timer

## Download NGINX configs

unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/http2.conf | sudo tee /etc/nginx/conf.d/http2.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/sites_default.conf | sudo tee /etc/nginx/conf.d/sites_default.conf
sudo sed -i 's/ipv4_1://g' /etc/nginx/conf.d/sites_default.conf
sudo sed -i 's/ipv6_1/::/g' /etc/nginx/conf.d/sites_default.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/tls.conf | sudo tee /etc/nginx/conf.d/tls.conf

sudo mkdir -p /etc/nginx/snippets
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/tls.conf | sudo tee /etc/nginx/snippets/tls.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/proxy.conf | sudo tee /etc/nginx/snippets/proxy.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/quic.conf | sudo tee /etc/nginx/snippets/quic.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/security.conf | sudo tee /etc/nginx/snippets/security.conf
unpriv curl https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/universal_paths.conf | sudo tee /etc/nginx/snippets/universal_paths.conf

