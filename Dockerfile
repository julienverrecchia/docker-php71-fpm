# PHP-FPM 7.1
FROM php:7.1-fpm-jessie

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        apt-transport-https \
        libmemcached-dev \
        libz-dev \
        libpq-dev \
        libjpeg-dev \
        libpng12-dev \
        libfreetype6-dev \
        libssl-dev \
        libmcrypt-dev \
        libpq-dev \
        libldap2-dev \
        openssl \
        libicu-dev \
        libxml2-dev \
        zlib1g-dev \
        ssmtp

# Basic
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-install mbstring mcrypt pcntl pdo_pgsql intl xmlrpc \
    && docker-php-ext-install opcache \
    && docker-php-ext-install zip

# SOAP
RUN docker-php-ext-configure soap --enable-soap \
    && docker-php-ext-install soap

# Memcached
RUN pecl install memcached-3.0.4 && \
    docker-php-ext-enable memcached

# Opcache
RUN docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install opcache
COPY ./config/opcache.ini /usr/local/etc/php/conf.d/

# INTL
RUN docker-php-ext-configure intl --enable-intl \
    && docker-php-ext-install intl

# Oracle (OCI8)
RUN curl -L -o /tmp/instantclient-sdk-12.2.zip http://bit.ly/2Bab3NM \
    && curl -L -o /tmp/instantclient-basic-12.2.zip http://bit.ly/2mBFHdA
RUN apt-get install -y unzip build-essential libaio1 re2c && \
    ln -s /usr/include/php5 /usr/include/php && \
    mkdir -p /opt/oracle/instantclient && \
    unzip -q /tmp/instantclient-basic-12.2.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_12_2 /opt/oracle/instantclient/lib && \
    unzip -q /tmp/instantclient-sdk-12.2.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_12_2/sdk/include /opt/oracle/instantclient/include && \
    ln -s /opt/oracle/instantclient/lib/libclntsh.so.12.1 /opt/oracle/instantclient/lib/libclntsh.so && \
    ln -s /opt/oracle/instantclient/lib/libocci.so.12.1 /opt/oracle/instantclient/lib/libocci.so && \
    echo /opt/oracle/instantclient/lib >> /etc/ld.so.conf && \
    ldconfig
RUN ls -l /opt/oracle/instantclient/lib && echo 'instantclient,/opt/oracle/instantclient/lib' | pecl install oci8
ADD ./config/oci8.ini /usr/local/etc/php/conf.d/20-oci8.ini
ADD ./config/oci8-test.php /tmp/oci8-test.php
RUN php /tmp/oci8-test.php

# SQL Server (sqlsrv)
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends debconf-utils gcc build-essential g++ unixodbc-dev msodbcsql mssql-tools locales \
    && echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc \
    && /bin/bash -c "source ~/.bashrc" \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && pecl install sqlsrv-4.1.6.1 \
    && docker-php-ext-enable sqlsrv

# ionCube Loader
ADD ./ext/ioncube_loader_lin_7.1.so /usr/local/lib/php/extensions/no-debug-non-zts-20160303/
ADD ./config/ioncube.ini /usr/local/etc/php/conf.d/00-ioncube.ini

# PHP Configuration
RUN sed -e '/9000/ s/^;*/;/' -i /usr/local/etc/php-fpm.d/zz-docker.conf
RUN sed -e '/9000/ s/^;*/;/' -i /usr/local/etc/php-fpm.d/www.conf
ADD ./config/php71.pool.conf /usr/local/etc/php-fpm.d/
ADD ./config/custom.php.ini /usr/local/etc/php/conf.d

# SSMTP
ADD ./config/ssmtp.conf /etc/ssmtp/ssmtp.conf
ADD ./config/php-ssmtp.ini /usr/local/etc/php/conf.d/php-smtp.ini

RUN apt-get install -y --no-install-recommends wget
RUN docker-php-ext-configure sockets \
    && docker-php-ext-install sockets

# Composer
RUN EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN ACTUAL_SIGNATURE="$(php -r "echo hash_file('SHA384', 'composer-setup.php');")"
RUN if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then >&2 echo 'ERROR: Invalid installer signature' ; rm composer-setup.php ; exit 1; fi;
RUN php composer-setup.php --quiet
RUN RESULT=$?
RUN rm composer-setup.php && mv composer.phar /usr/local/bin/composer

# PHPUnit
RUN wget https://phar.phpunit.de/phpunit-6.5.phar \
    && chmod +x phpunit-6.5.phar \
    && mv phpunit-6.5.phar /usr/local/bin/phpunit

# PHP CS FIXER
RUN wget https://cs.sensiolabs.org/download/php-cs-fixer-v2.phar -O php-cs-fixer \
    && chmod a+x php-cs-fixer \
    && mv php-cs-fixer /usr/local/bin/php-cs-fixer

# Clean up
RUN apt-get clean \
    && rm -r /var/lib/apt/lists/*

RUN usermod -u 1000 www-data

WORKDIR /var/www

CMD ["php-fpm"]

LABEL \
    maintainer="Julien Verrecchia" \
    version="2018.07.18"
