# Ubuntu 24.04 LEMP Drupal

First you need to run the following scripts:

- https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/Ubuntu-24.04-Server.sh
- https://github.com/TommyTran732/Linux-Setup-Scripts/blob/main/sample-scripts-Ubuntu-24.04-LEMP.sh

## Install composer

```
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo chown root:root composer.phar
sudo mv composer.phar /usr/local/bin
```

## Setup Directory Structure

```
# Add unprivileged user for drupal
sudo useradd -U -m -s /bin/bash drupal

# Make drupal directory

sudo mkdir -p /srv/drupal
sudo chown drupal:drupal /srv/drupal

# Setup ACL
sudo apt install -y acl
sudo setfacl -dm u:nginx:rwx /srv/drupal
sudo setfacl -m u:nginx:rwx /srv/drupal
```

## Install Drupal

Switch to the `drupal` user: 

```
sudo su - drupal
```

As the drupal user, run:

```
cd /srv/drupal
composer create-project drupal/recommended-project drupal.yourdomain.tld
```

## Generate an SSL certificate

```
certbot certonly --nginx --no-eff-email \
    --key-type ecdsa --must-staple \
    --deploy-hook "certbot-ocsp-fetcher -o /var/cache/certbot-ocsp-fetcher" \
    --cert-name drupal.yourdomain.tld \
    -d drupal.yourdomain.tld
```

## NGINX configuration file

Put the following file in `/etc/nginx/conf.d/sites_drupal.conf`:

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
    ssl_stapling_file  /var/cache/certbot-ocsp-fetcher/drupal.yourdomain.tld.der;

    include snippets/hsts.conf;
    include snippets/security.conf;
    include snippets/cross-origin-security.conf;
    include snippets/quic.conf;

    index index.php;
    root /srv/drupal/drupal.yourdomain.tld/web;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```