ARG PHP_VERSION=7.4

##
# Prepare Invoiceninja sources for reuse later
##
FROM php:${PHP_VERSION}-fpm-alpine AS php-base
ARG SNIPEIT_VERSION=5.1.6
LABEL maintainer="Johannes Engel <jcnengel@gmail.com>"

RUN set -eux; \
    apk update \
    && apk add --no-cache \
    curl libldap \
    libarchive-tools; \
    mkdir -p /var/www/app

##
# Install missing PHP extensions
##
RUN apk update \
    && apk add --no-cache git gmp-dev freetype-dev libjpeg-turbo-dev curl-dev \
    coreutils chrpath fontconfig libpng-dev oniguruma-dev zip libzip libzip-dev \
    openldap-dev libxml2-dev mariadb-client \
    && docker-php-ext-configure gmp \
    && docker-php-ext-install json pdo pdo_mysql mbstring tokenizer curl ldap fileinfo zip bcmath xml gd \
    && echo "php_admin_value[error_reporting] = E_ALL & ~E_NOTICE & ~E_WARNING & ~E_STRICT & ~E_DEPRECATED" >> /usr/local/etc/php-fpm.d/www.conf \
    && apk del gmp-dev freetype-dev libjpeg-turbo-dev libpng-dev oniguruma-dev \
    libzip-dev curl-dev openldap-dev libxml2-dev

RUN { \
	echo 'opcache.memory_consumption=128'; \
	echo 'opcache.interned_strings_buffer=8'; \
	echo 'opcache.max_accelerated_files=4000'; \
	echo 'opcache.revalidate_freq=60'; \
	echo 'opcache.fast_shutdown=1'; \
	echo 'opcache.enable_cli=1'; \
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# Install composer and related requirements
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin \
	--filename=composer

WORKDIR /var/www/app
    
RUN curl -o /tmp/snipeit.tar.gz -LJ0 https://github.com/snipe/snipe-it/archive/v${SNIPEIT_VERSION}.tar.gz \
    && bsdtar --strip-components=1 -C /var/www/app -xf /tmp/snipeit.tar.gz \
    && rm /tmp/snipeit.tar.gz \
    && cp -R /var/www/app/storage /var/www/app/docker-backup-storage  \
    && cp -R /var/www/app/public /var/www/app/docker-backup-public  \
    && mkdir -p /var/www/app/storage \
    && cp /var/www/app/.env.example /var/www/app/.env \
    && composer install --no-dev

VOLUME /var/www/app/public

# Create local user
ENV SNIPEIT_USER=snipeit
RUN addgroup -S "${SNIPEIT_USER}" \
	&& adduser --disabled-password --gecos "" --home "/var/www/app" \
	--ingroup "${SNIPEIT_USER}" --no-create-home "${SNIPEIT_USER}"; \
	addgroup "${SNIPEIT_USER}" www-data; \
	chown -R "${SNIPEIT_USER}":"${SNIPEIT_USER}" /var/www/app

USER $SNIPEIT_USER

ENV APP_ENV production

CMD ["php-fpm"]
