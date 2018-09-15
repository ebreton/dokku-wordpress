#!/bin/bash

# parse DATABASE_URL

# extract the protocol
proto="$(echo ${DATABASE_URL} | grep :// | sed -e's,^\(.*://\).*,\1,g')"
# remove the protocol
url="$(echo ${DATABASE_URL/$proto/})"
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
echo "  host: $hostname"
echo "  port: $port"
echo "  path: $path"

# create db
mysql -u $user -h $hostname --password=$pass -e "CREATE DATABASE IF NOT EXISTS $path;"

# create wp-config.php file
sudo -u www-data wp config create --dbuser=$user --dbpass=$pass --dbhost=$hostname --dbname=$path

# install WP
sudo -u www-data wp core install --url="${SITE_URL}" --title="${SITE_TITLE}" --admin_user="${WP_USER}" --admin_password="${WP_PASSWORD}" --admin_email=${WP_EMAIL} --skip-email
