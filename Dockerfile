FROM wordpress:4.9-php5.6-apache

RUN apt-get update \
	&& apt-get install -y \
        sudo \
        mysql-client \
        libmemcached-dev \
        tidy \
        csstidy \
        zlib1g-dev \
	&& mkdir -p /usr/src/php/ext

RUN curl -o memcached.tgz -SL http://pecl.php.net/get/memcached-2.2.0.tgz \
    && tar -xf memcached.tgz -C /usr/src/php/ext/ \
    && rm memcached.tgz \
    && mv /usr/src/php/ext/memcached-2.2.0 /usr/src/php/ext/memcached

RUN curl -o memcache.tgz -SL http://pecl.php.net/get/memcache-3.0.8.tgz \
    && tar -xf memcache.tgz -C /usr/src/php/ext/ \
    && rm memcache.tgz \
    && mv /usr/src/php/ext/memcache-3.0.8 /usr/src/php/ext/memcache

RUN curl -o zip.tgz -SL http://pecl.php.net/get/zip-1.13.1.tgz \
    && tar -xf zip.tgz -C /usr/src/php/ext/ \
    && rm zip.tgz \
    && mv /usr/src/php/ext/zip-1.13.1 /usr/src/php/ext/zip

RUN docker-php-ext-install memcached \
    && docker-php-ext-install memcache \
    && docker-php-ext-install zip

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

RUN echo "alias wp='sudo -u www-data wp'" >> /root/.bashrc \
    && sed -i "s/# alias l/alias l/g" /root/.bashrc


COPY ./etc/uploads.ini /usr/local/etc/php/conf.d/uploads.ini
COPY ./etc/mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf

COPY ./var/object-cache.php /var/object-cache.php

COPY ./bin/init.sh /usr/local/bin/
COPY ./bin/post-init.sh /usr/local/bin/
