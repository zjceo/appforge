#!/bin/bash

# Script para renovar certificados SSL usando certbot

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: $0 <dominio> [email]"
    echo "Ejemplo: $0 ejemplo.com admin@ejemplo.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-admin@$DOMAIN}

echo "🔐 Renovando certificado SSL para $DOMAIN..."
echo ""

# Verificar que certbot esté instalado
if ! command -v certbot &> /dev/null; then
    echo "❌ certbot no está instalado"
    echo "Instala certbot con: sudo apt-get install certbot"
    exit 1
fi

# Renovar certificado
certbot renew --cert-name "$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive

echo ""
echo "✅ Certificado SSL renovado para $DOMAIN"
echo ""

# Si usas nginx o apache, reinicia el servicio
read -p "¿Deseas reiniciar nginx? (y/n): " restart_nginx
if [ "$restart_nginx" = "y" ]; then
    sudo systemctl restart nginx
    echo "✅ nginx reiniciado"
fi

read -p "¿Deseas reiniciar apache2? (y/n): " restart_apache
if [ "$restart_apache" = "y" ]; then
    sudo systemctl restart apache2
    echo "✅ apache2 reiniciado"
fi

echo ""
echo "✨ Proceso completado"

