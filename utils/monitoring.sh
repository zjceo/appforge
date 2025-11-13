#!/bin/bash

# Script para monitorear el estado de las aplicaciones instaladas

set -e

echo "📊 Estado de las aplicaciones AppForge"
echo "========================================"
echo ""

# Buscar todos los directorios con docker-compose.yml
FOUND=false

for app_dir in */; do
    if [ -f "${app_dir}docker-compose.yml" ]; then
        FOUND=true
        app_name=$(basename "$app_dir")
        echo "📦 $app_name"
        echo "----------------------------------------"
        
        cd "$app_dir"
        
        # Verificar estado de los contenedores
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            echo "  ✅ Estado: Ejecutándose"
            
            # Mostrar contenedores
            echo "  📋 Contenedores:"
            docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tail -n +2 | sed 's/^/    /'
        else
            echo "  ⏸️  Estado: Detenido"
        fi
        
        # Mostrar uso de recursos
        echo ""
        echo "  💾 Uso de recursos:"
        CONTAINERS=$(docker-compose ps -q 2>/dev/null)
        if [ -n "$CONTAINERS" ]; then
            docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $CONTAINERS 2>/dev/null | tail -n +2 | sed 's/^/    /' || echo "    No disponible"
        else
            echo "    No hay contenedores en ejecución"
        fi
        
        # Mostrar volúmenes
        VOLUMES=$(docker-compose config --volumes 2>/dev/null || echo "")
        if [ -n "$VOLUMES" ]; then
            echo ""
            echo "  📦 Volúmenes:"
            for volume in $VOLUMES; do
                SIZE=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "N/A")
                echo "    - $volume ($SIZE)"
            done
        fi
        
        cd ..
        echo ""
    fi
done

if [ "$FOUND" = false ]; then
    echo "⚠️  No se encontraron aplicaciones instaladas"
    echo ""
    echo "Para instalar una aplicación, ejecuta:"
    echo "  ./install.sh"
fi

echo ""
echo "✨ Monitoreo completado"

