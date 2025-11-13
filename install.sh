#!/bin/bash

# Script principal de instalación de AppForge

set -e

echo "🚀 AppForge - Instalador de aplicaciones"
echo "========================================="
echo ""

# Verificar que Docker y Docker Compose están instalados
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Por favor, instala Docker primero."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado. Por favor, instala Docker Compose primero."
    exit 1
fi

echo "✅ Docker y Docker Compose detectados"
echo ""

# Menú de selección de aplicación
echo "Selecciona la aplicación que deseas instalar:"
echo ""
echo "1) n8n"
echo "2) NocoDB"
echo "3) Evolution API"
echo "4) Typebot"
echo "5) Chatwoot"
echo "6) Flowise"
echo "7) MinIO"
echo "8) MongoDB"
echo "9) Redis"
echo "10) RabbitMQ"
echo ""
read -p "Ingresa el número de la aplicación: " choice

case $choice in
    1) APP_NAME="n8n" ;;
    2) APP_NAME="nocodb" ;;
    3) APP_NAME="evolution-api" ;;
    4) APP_NAME="typebot" ;;
    5) APP_NAME="chatwoot" ;;
    6) APP_NAME="flowise" ;;
    7) APP_NAME="minio" ;;
    8) APP_NAME="mongodb" ;;
    9) APP_NAME="redis" ;;
    10) APP_NAME="rabbitmq" ;;
    *)
        echo "❌ Opción inválida"
        exit 1
        ;;
esac

TEMPLATE_DIR="templates/$APP_NAME"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Template no encontrado para $APP_NAME"
    exit 1
fi

echo ""
read -p "¿Dónde deseas instalar $APP_NAME? (presiona Enter para usar ./$APP_NAME): " INSTALL_DIR

INSTALL_DIR=${INSTALL_DIR:-"./$APP_NAME"}

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  El directorio $INSTALL_DIR ya existe"
    read -p "¿Deseas continuar? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        exit 0
    fi
fi

mkdir -p "$INSTALL_DIR"

echo ""
echo "📋 Copiando archivos de template..."
cp "$TEMPLATE_DIR/docker-compose.yml" "$INSTALL_DIR/"

if [ -f "$TEMPLATE_DIR/.env.example" ]; then
    if [ -f "$INSTALL_DIR/.env" ]; then
        echo "⚠️  El archivo .env ya existe, no se sobrescribirá"
    else
        cp "$TEMPLATE_DIR/.env.example" "$INSTALL_DIR/.env"
        echo "✅ Archivo .env creado. Por favor, edita las variables de entorno según tus necesidades."
    fi
fi

if [ -f "$TEMPLATE_DIR/README.md" ]; then
    cp "$TEMPLATE_DIR/README.md" "$INSTALL_DIR/"
fi

echo ""
echo "✅ Instalación completada en $INSTALL_DIR"
echo ""
echo "Próximos pasos:"
echo "1. Edita el archivo .env si es necesario"
echo "2. Ejecuta: cd $INSTALL_DIR && docker-compose up -d"
echo ""

