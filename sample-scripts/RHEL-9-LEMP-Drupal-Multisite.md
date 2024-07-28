# RHEL 9 LEMP Drupal Multisite

First you need to run the following scripts:

- https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/RHEL-9.sh
- https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/sample-scripts/RHEL-9-LEMP.sh

## Install composer

```
sudo dnf install -y composer
```

## Install other necessary packages

```
sudo dnf install -y php-gd php-opcache php-pdo unzip
```

## Setup Directory Structure

```
# Add unprivileged user for drupal
sudo useradd -U -m -s /bin/bash drupal

# Make drupal directory

sudo mkdir -p /srv/drupal
sudo chown drupal:drupal /srv/drupal

# Setup ACL
sudo setfacl -dm u:nginx:rwx /srv/drupal
sudo setfacl -m u:nginx:rwx /srv/drupal

# Setup SELinux context
sudo semanage fcontext -a -t httpd_sys_content_t "$(realpath /srv/drupal)(/.*)?"
sudo restorecon -Rv /srv/drupal
```

## Install Drupal

Switch to the `drupal` user: 

```
sudo su - drupal
```

As the drupal user, run:

```
# This is only needed on RHEL, for some reason upstream composer on Ubuntu sets the correct permission regardless of umask
umask 022

cd /srv/drupal
composer create-project drupal/recommended-project drupal.yourdomain.tld
cp /srv/drupal/drupal.yourdomain.tld/web/sites/default/default.settings.php /srv/drupal/drupal.yourdomain.tld./web/sites/default/settings.php
```

Exit the drupal user:
```
exit
```

## Generate an SSL certificate

```
certbot certonly --nginx --no-eff-email \
    --key-type ecdsa \
    --cert-name drupal.yourdomain.tld \
    -d drupal.yourdomain.tld
```

## NGINX configuration file

As root, download [this file](https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/sample-configurations/snippets/security-drupal-no-proxy.conf) and put it in `/etc/nginx/snippets/security-drupal-no-proxy.conf`

As root, put the following file in `/etc/nginx/conf.d/sites_drupal.conf`:

```
server {
    listen 443 quic reuseport;
    listen 443 ssl;
    listen [::]:443 quic reuseport;
    listen [::]:443 ssl;

    server_name drupal.yourdomain.tld;

    ssl_certificate /etc/letsencrypt/live/drupal.yourdomain.tld/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/drupal.yourdomain.tld/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/drupal.yourdomain.tld/chain.pem;

    include snippets/hsts.conf;
    include snippets/security-drupal-no-proxy.conf;
    include snippets/cross-origin-security.conf;
    include snippets/quic.conf;

    add_header Content-Security-Policy "default-src 'none'; connect-src 'self'; font-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; base-uri 'none'; block-all-mixed-content; form-action 'self'; frame-ancestors 'self'; upgrade-insecure-requests";

    index index.php;
    root /srv/drupal/drupal.yourdomain.tld/web;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php-fpm/www.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**Notes**: `listen 443 quic reuseport;` is only needed once. If you plan to have multiple vhosts on this setup with SSL, consider making a dedicated vhost for this config so that it is nicer and easier to manage. An example can be found [here](https://github.com/TommyTran732/NGINX-Configs/blob/main/etc/nginx/conf.d/sites_default_quic.conf).

## Setup the Database for Drupal

As root, log into MariaDB:

```
mariadb -uroot
```

Run the following queries:
```
CREATE DATABASE drupal_default CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'drupal_default'@'127.0.0.1' IDENTIFIED BY 'yourPassword';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON drupal.* TO 'drupal_default'@'127.0.0.1';
exit
```

## Configure Drupal

Go to drupal.yourdomain.tld and follow the prompts.

Switch to the `drupal` user: 

```
sudo su - drupal
```

As the drupal user, run:

```
chmod 400 /srv/drupal/drupal.yourdomain.tld/web/sites/default/settings.php
setfacl -m u:nginx:r /srv/drupal/drupal.yourdomain.tld/web/sites/default/settings.php
```
