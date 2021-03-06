#!/bin/bash

if grep --quiet memcached_servers wp-config.php; then
  echo "Config already adjusted with memcached, email"
  exit 0
else
  echo "Customizing wp-config.php, enabling cache"
fi

# parse MEMCACHED_URL

# extract the protocol
proto="$(echo ${MEMCACHED_URL} | grep :// | sed -e's,^\(.*://\).*,\1,g')"
# remove the protocol
url="$(echo ${MEMCACHED_URL/$proto/})"
# extract the user (if any)
credentials="$(echo $url | grep @ | cut -d@ -f1)"
user="$(echo $credentials | cut -d: -f1)"
pass="$(echo ${credentials/$user/} | cut -d: -f2)"
# extract the host
host="$(echo ${url/$credentials@/} | cut -d/ -f1)"
hostname="$(echo $host | cut -d: -f1)"
# by request - try to extract the port
port="$(echo $host | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
# extract the path (if any)
path="$(echo $url | grep / | cut -d/ -f2-)"

echo "url: $url"
echo "  proto: $proto"
echo "  user: $user"
echo "  pass: $pass"
echo "  hostname: $hostname"
echo "  port: $port"
echo "  path: $path"

# add object-cache and fix permissions
cp /var/object-cache.php /var/www/html/wp-content/
chown -R www-data:www-data /var/www/html

# add lines to wp-config.php
echo "
// Force SSL and avoid infinite loops behind reverse proxy
define( 'FORCE_SSL', true );
define( 'FORCE_SSL_LOGIN', true );
define( 'FORCE_SSL_ADMIN', true );

if (strpos(\$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false)
  	\$_SERVER['HTTPS']='on';

// allow wordpress to modify files in-place, i.e without FTP
define('FS_METHOD','direct');
" >> /var/www/html/wp-config.php

sed -i "s/<?php/<?php\n\ndefine( 'WP_CACHE_KEY_SALT', '$(hostname)' );\ndefine( 'WP_CACHE', true );\n\n\$memcached_servers = array(\n    'default' => array(\n        '$hostname:$port'\n    )\n);\n/" /var/www/html/wp-config.php
