FROM php:8.4-fpm AS builder

WORKDIR /var/www

ARG COMPOSER_CACHE_KEY
ARG NPM_CACHE_KEY
ENV COMPOSER_CACHE_DIR=/tmp/composer-cache

RUN apt-get update && apt-get install -y \
    nodejs \
    npm \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/tmp/composer-cache \
    composer install --no-interaction --no-dev --prefer-dist --optimize-autoloader --no-scripts

COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline --no-audit --no-fund

COPY . .

RUN --mount=type=cache,target=/root/.npm \
    npm run build

RUN npm prune --production

FROM php:8.4-fpm-alpine AS php

WORKDIR /var/www

COPY docker/php/prod.ini /usr/local/etc/php/conf.d/99-prod.ini

RUN apk add --no-cache --update \
    freetype \
    libjpeg-turbo \
    libpng \
    libzip \
    oniguruma \
    fcgi \
    rsync \
    && apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    oniguruma-dev \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath zip gd \
    && apk del .build-deps

COPY --from=builder /var/www /var/www

RUN rm -rf public

COPY --from=builder /var/www/public /var/www/public_assets

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 9000

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["php-fpm"]

FROM php AS development

RUN apk add --no-cache --update git

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/tmp/composer-cache \
    composer install --no-interaction --prefer-dist --optimize-autoloader

COPY phpunit.xml ./
COPY tests ./tests