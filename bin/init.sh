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

# create wp-config.php file
wp config create  --dbuser=$user --dbpass=$pass --dbhost=$hostname --dbport=$port  --dbname=$path
