#!/bin/bash

# Script para hacer backup de una aplicación instalada

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: $0 <nombre-aplicacion>"
    echo "Ejemplo: $0 n8n"
    exit 1
fi

APP_NAME=$1
APP_DIR="./$APP_NAME"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${APP_NAME}_${TIMESTAMP}.tar.gz"

if [ ! -d "$APP_DIR" ]; then
    echo "❌ El directorio $APP_DIR no existe"
    exit 1
fi

if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
    echo "❌ No se encontró docker-compose.yml en $APP_DIR"
    exit 1
fi

echo "📦 Haciendo backup de $APP_NAME..."

mkdir -p "$BACKUP_DIR"

# Obtener los nombres de los volúmenes del docker-compose
cd "$APP_DIR"
VOLUMES=$(docker-compose config --volumes)

if [ -z "$VOLUMES" ]; then
    echo "⚠️  No se encontraron volúmenes en docker-compose.yml"
    echo "📋 Haciendo backup de archivos de configuración solamente..."
    cd ..
    tar czf "$BACKUP_FILE" "$APP_NAME" --exclude="$APP_NAME/node_modules" --exclude="$APP_NAME/.git"
else
    echo "📋 Haciendo backup de volúmenes y archivos de configuración..."
    
    # Backup de volúmenes
    for volume in $VOLUMES; do
        echo "  → Backup del volumen: $volume"
        docker run --rm \
            -v "$volume:/data:ro" \
            -v "$(pwd)/../$BACKUP_DIR:/backup" \
            ubuntu:latest \
            tar czf "/backup/${volume}_${TIMESTAMP}.tar.gz" -C /data .
    done
    
    cd ..
    
    # Backup de archivos de configuración
    tar czf "$BACKUP_FILE" "$APP_NAME" --exclude="$APP_NAME/node_modules" --exclude="$APP_NAME/.git"
fi

echo ""
echo "✅ Backup completado: $BACKUP_FILE"
echo ""

