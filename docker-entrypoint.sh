#!/bin/sh
set -e

echo "Sincronizando assets da imagem para o volume compartilhado..."
rsync -av --delete /var/www/public_assets/ /var/www/public/
chown -R www-data:www-data /var/www/public

if [ ! -L "/var/www/public/storage" ]; then
    chown -R www-data:www-data /var/www/storage
fi

exec "$@"