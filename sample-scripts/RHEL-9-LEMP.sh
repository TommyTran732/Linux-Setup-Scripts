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

# Assumes that it is run AFTER https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/RHEL.sh

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

# Remove hardened_malloc (It breaks php-fpm)
sudo dnf remove -y hardened_malloc

# Install NGINX
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/Linux-Setup-Scripts/main/etc/yum.repos.d/nginx.repo | sudo tee /etc/yum.repos.d/nginx.repo > /dev/null
sudo chmod 644 /etc/yum.repos.d/nginx.repo
sudo dnf install -y nginx

# Install certbot
sudo dnf install -y certbot python3-certbot-nginx

# Install PHP
sudo subscription-manager repos --enable "codeready-builder-for-rhel-9-$(arch)-rpms"
sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
sudo dnf module install -y php:remi-8.3/common
sudo systemctl enable --now php-fpm

# Install MariaDB
unpriv curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
sudo dnf install -y MariaDB-server
sudo systemctl enable --now mariadb

# Secure MariaDB
output "Running mariadb-secure-installation." 
output "You should answer yes to everything except setting the root password."
output "This is already done via the UNIX socket if you switch it with the prompts so you should be okay."
sudo mariadb-secure-installation

# Run NGINX Setup script
unpriv curl -LsS https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/setup.sh | sudo bash

# Fix PHP permission
sudo sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf
sudo sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf
sudo chgrp nginx /var/lib/php/opcache /var/lib/php/session /var/lib/php/wsdlcache
sudo systemctl restart php-fpm
