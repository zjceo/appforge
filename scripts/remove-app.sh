#!/bin/bash

# Script para eliminar una aplicación instalada

set -e

if [ -z "$1" ]; then
    echo "❌ Uso: $0 <nombre-aplicacion>"
    echo "Ejemplo: $0 n8n"
    exit 1
fi

APP_NAME=$1
APP_DIR="./$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
    echo "❌ El directorio $APP_DIR no existe"
    exit 1
fi

echo "⚠️  ATENCIÓN: Esta acción eliminará:"
echo "   - El directorio $APP_DIR"
if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo "   - Los contenedores de Docker"
    cd "$APP_DIR"
    VOLUMES=$(docker-compose config --volumes 2>/dev/null || echo "")
    if [ -n "$VOLUMES" ]; then
        echo "   - Los siguientes volúmenes de Docker:"
        for volume in $VOLUMES; do
            echo "     * $volume"
        done
        echo ""
        read -p "¿Deseas mantener los volúmenes? (y/n): " keep_volumes
    fi
    cd ..
fi

read -p "¿Estás seguro de que deseas continuar? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Operación cancelada"
    exit 0
fi

# Detener y eliminar contenedores
if [ -f "$APP_DIR/docker-compose.yml" ]; then
    echo "🛑 Deteniendo y eliminando contenedores..."
    cd "$APP_DIR"
    docker-compose down
    
    # Eliminar volúmenes si el usuario lo desea
    if [ "$keep_volumes" != "y" ] && [ -n "$VOLUMES" ]; then
        echo "🗑️  Eliminando volúmenes..."
        for volume in $VOLUMES; do
            docker volume rm "$volume" 2>/dev/null || echo "  ⚠️  No se pudo eliminar el volumen $volume (puede estar en uso)"
        done
    fi
    
    cd ..
fi

# Eliminar directorio
echo "🗑️  Eliminando directorio..."
rm -rf "$APP_DIR"

echo ""
echo "✅ Aplicación $APP_NAME eliminada correctamente"
echo ""

