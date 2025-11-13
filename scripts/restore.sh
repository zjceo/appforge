#!/bin/bash

# Script para restaurar un backup de una aplicación

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Uso: $0 <nombre-aplicacion> <archivo-backup>"
    echo "Ejemplo: $0 n8n backups/n8n_20240101_120000.tar.gz"
    exit 1
fi

APP_NAME=$1
BACKUP_FILE=$2
APP_DIR="./$APP_NAME"
BACKUP_DIR="./backups"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ El archivo de backup $BACKUP_FILE no existe"
    exit 1
fi

echo "📥 Restaurando backup de $APP_NAME..."
echo "⚠️  Esta acción sobrescribirá los datos actuales de $APP_NAME"
read -p "¿Deseas continuar? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Operación cancelada"
    exit 0
fi

# Detener la aplicación si está corriendo
if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo "🛑 Deteniendo la aplicación..."
    cd "$APP_DIR"
    docker-compose down 2>/dev/null || true
    cd ..
fi

# Restaurar archivos de configuración
echo "📋 Extrayendo archivos de configuración..."
tar xzf "$BACKUP_FILE" -C . 2>/dev/null || true

# Restaurar volúmenes si existen
if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/docker-compose.yml" ]; then
    cd "$APP_DIR"
    VOLUMES=$(docker-compose config --volumes)
    
    for volume in $VOLUMES; do
        VOLUME_BACKUP=$(find "../$BACKUP_DIR" -name "${volume}_*.tar.gz" | sort | tail -1)
        if [ -n "$VOLUME_BACKUP" ]; then
            echo "  → Restaurando volumen: $volume"
            docker run --rm \
                -v "$volume:/data" \
                -v "$(pwd)/..:/backup:ro" \
                ubuntu:latest \
                sh -c "rm -rf /data/* && tar xzf /backup/$VOLUME_BACKUP -C /data"
        fi
    done
    
    cd ..
fi

echo ""
echo "✅ Restauración completada"
echo ""
echo "Próximos pasos:"
echo "1. Revisa la configuración en $APP_DIR/.env"
echo "2. Inicia la aplicación: cd $APP_DIR && docker-compose up -d"
echo ""

