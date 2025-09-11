FROM php:8.4-fpm AS builder

WORKDIR /var/www

RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --prefer-dist --optimize-autoloader --no-scripts

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

RUN npm run build

RUN npm prune --production

FROM php:8.4-fpm-alpine AS php

WORKDIR /var/www

COPY docker/php/prod.ini /usr/local/etc/php/conf.d/99-prod.ini

RUN apk add --no-cache --update \
    $PHPIZE_DEPS \
    libzip-dev \
    oniguruma-dev \
    libexif-dev \
    libpng-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath zip gd \
    && apk del $PHPIZE_DEPS

COPY --from=builder /var/www /var/www

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]

FROM php AS development

RUN apk add --no-cache --update git

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./

RUN composer install --no-interaction --prefer-dist --optimize-autoloader

COPY phpunit.xml ./
COPY tests ./tests
