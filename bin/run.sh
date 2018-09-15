#!/bin/bash

if grep --quiet memcached_servers wp-config.php; then
  echo "Config already adjusted with memcached, email"
  exit 0
else
  echo "Customizing wp-config.php, enabling cache"
fi

cp /var/object-cache.php /var/www/html/wp-content/
chown -R www-data:www-data /var/www/html

# following variables are expected from .env file
export GMAIL_USERNAME=${GMAIL_USERNAME:-"no gmail provided"}
export GMAIL_APP_PASSWORD=${GMAIL_APP_PASSWORD:-"no password provided"}
export FROM_NAME=${FROM_NAME:-"no name provided"}

# add lines to wp-config.php
echo "
// allow wordpress to modify files in-place, i.e without FTP
define('FS_METHOD','direct');

// configure phpmailer
add_action( 'phpmailer_init', 'mail_relay' );
function mail_relay( \$phpmailer ) {
    \$phpmailer->isSMTP();
    \$phpmailer->Host = 'smtp.gmail.com';
    \$phpmailer->SMTPAutoTLS = true;
    \$phpmailer->SMTPAuth = true; // Force it to use Username and Password to authenticate
    \$phpmailer->Port = 465;
    \$phpmailer->Username = ${GMAIL_USERNAME};
    \$phpmailer->Password = ${GMAIL_APP_PASSWORD};

    // Additional settings
    \$phpmailer->SMTPSecure = 'ssl'; // Choose SSL or TLS, if necessary for your server
    \$phpmailer->From = ${GMAIL_USERNAME};
    \$phpmailer->FromName = ${FROM_NAME};
}" >> /var/www/html/wp-config.php

sed -i "s/<?php/<?php\n\ndefine( 'WP_CACHE_KEY_SALT', '${WORDPRESS_DB_NAME}' );\ndefine( 'WP_CACHE', true );\n\n\$memcached_servers = array(\n    'default' => array(\n        'memcached:11211'\n    )\n);\n\n\$url = parse_url(getenv('DATABASE_URL'));\n/" /var/www/html/wp-config.php
sed -i "s/'DB_NAME', 'DB_NAME'/'DB_NAME', trim(\$url['path'], '\/')/" /var/www/html/wp-config.php
sed -i "s/'DB_USER', 'DB_USER'/'DB_USER', trim(\$url['user'])/" /var/www/html/wp-config.php
sed -i "s/'DB_PASSWORD', 'DB_PASSWORD'/'DB_PASSWORD', trim(\$url['pass'])/" /var/www/html/wp-config.php
sed -i "s/'DB_HOST', 'DB_HOST'/'DB_HOST', trim(\$url['host'])/" /var/www/html/wp-config.php
