#!/bin/bash

# Script para actualizar todas las aplicaciones o una específica

set -e

if [ -z "$1" ]; then
    echo "📦 Actualizando todas las aplicaciones instaladas..."
    echo ""
    
    # Buscar todos los directorios con docker-compose.yml
    for app_dir in */; do
        if [ -f "${app_dir}docker-compose.yml" ]; then
            app_name=$(basename "$app_dir")
            echo "🔄 Actualizando $app_name..."
            cd "$app_dir"
            docker-compose pull
            docker-compose up -d
            cd ..
            echo "✅ $app_name actualizado"
            echo ""
        fi
    done
else
    APP_NAME=$1
    APP_DIR="./$APP_NAME"
    
    if [ ! -d "$APP_DIR" ]; then
        echo "❌ El directorio $APP_DIR no existe"
        exit 1
    fi
    
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo "❌ No se encontró docker-compose.yml en $APP_DIR"
        exit 1
    fi
    
    echo "🔄 Actualizando $APP_NAME..."
    cd "$APP_DIR"
    docker-compose pull
    docker-compose up -d
    cd ..
    echo "✅ $APP_NAME actualizado"
fi

echo ""
echo "✨ Actualización completada"

