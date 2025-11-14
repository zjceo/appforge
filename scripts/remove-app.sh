#!/bin/bash

# ============================================
# APPFORGE - Script de Eliminación de Apps
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Directorios
APPS_DIR="./apps"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Función de ayuda
show_help() {
    echo -e "${BLUE}Uso:${NC} $0 [opciones] <app-name>"
    echo ""
    echo "Opciones:"
    echo "  -b, --backup        Hacer backup antes de eliminar"
    echo "  -v, --keep-volumes  Mantener los volúmenes (no eliminar datos)"
    echo "  -f, --force         No pedir confirmación"
    echo "  -p, --purge         Eliminar todo (incluido backups)"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 n8n-1                    # Eliminar con confirmación"
    echo "  $0 -b n8n-1                 # Backup antes de eliminar"
    echo "  $0 -v nocodb-1              # Eliminar pero mantener datos"
    echo "  $0 -f -p typebot-1          # Eliminar todo sin preguntar"
}

# Listar aplicaciones instaladas
list_apps() {
    echo -e "${BLUE}📦 Aplicaciones instaladas:${NC}"
    echo ""
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No hay aplicaciones instaladas${NC}"
        return
    fi
    
    local count=1
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            local app_name=$(basename "$app_dir")
            
            cd "$app_dir"
            
            # Estado
            local status="⏸️  Detenido"
            if docker-compose ps 2>/dev/null | grep -q "Up"; then
                status="✅ Ejecutándose"
            fi
            
            # Volúmenes
            local volumes=$(docker-compose config --volumes 2>/dev/null | wc -l)
            
            # Tamaño aproximado
            local size="N/A"
            if [ "$volumes" -gt 0 ]; then
                local total_size=0
                for vol in $(docker-compose config --volumes 2>/dev/null); do
                    if docker volume ls | grep -q "$vol"; then
                        local vol_size=$(docker system df -v 2>/dev/null | grep "$vol" | awk '{print $3}' | sed 's/MB//' | sed 's/GB/*1024/' | bc 2>/dev/null || echo "0")
                        total_size=$(echo "$total_size + $vol_size" | bc 2>/dev/null || echo "0")
                    fi
                done
                if [ "$total_size" != "0" ]; then
                    size="${total_size}MB"
                fi
            fi
            
            echo -e "  ${BLUE}[$count]${NC} $app_name - $status - $volumes volumen(es) - $size"
            
            cd - > /dev/null
            ((count++))
        fi
    done
    echo ""
}

# Crear backup antes de eliminar
backup_before_remove() {
    local app_name=$1
    
    echo -e "${YELLOW}📦 Creando backup de seguridad...${NC}"
    
    if [ -f "./scripts/backup.sh" ]; then
        ./scripts/backup.sh "$app_name"
        echo -e "${GREEN}✓ Backup creado${NC}"
        echo ""
    else
        echo -e "${YELLOW}⚠️  Script de backup no encontrado, saltando...${NC}"
        echo ""
    fi
}

# Eliminar aplicación
remove_app() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    
    if [ ! -d "$app_dir" ]; then
        echo -e "${RED}❌ El directorio $app_dir no existe${NC}"
        return 1
    fi
    
    if [ ! -f "$app_dir/docker-compose.yml" ]; then
        echo -e "${RED}❌ No se encontró docker-compose.yml en $app_dir${NC}"
        return 1
    fi
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🗑️  Eliminando $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cd "$app_dir"
    
    # Obtener información antes de eliminar
    local containers=$(docker-compose ps -q 2>/dev/null | wc -l)
    local volumes=$(docker-compose config --volumes 2>/dev/null)
    local volume_count=$(echo "$volumes" | wc -l)
    
    if [ -z "$volumes" ]; then
        volume_count=0
    fi
    
    cd - > /dev/null
    
    # Mostrar lo que se eliminará
    echo -e "${YELLOW}⚠️  Se eliminarán los siguientes elementos:${NC}"
    echo -e "  • Directorio: ${CYAN}$app_dir${NC}"
    echo -e "  • Contenedores: ${CYAN}$containers${NC}"
    
    if [ "$KEEP_VOLUMES" = true ]; then
        echo -e "  • Volúmenes: ${GREEN}SE MANTENDRÁN ($volume_count)${NC}"
    else
        echo -e "  • Volúmenes: ${RED}$volume_count${NC}"
    fi
    
    if [ "$PURGE_BACKUPS" = true ]; then
        local backup_count=$(find "$BACKUP_DIR" -name "${app_name}_*" 2>/dev/null | wc -l)
        echo -e "  • Backups: ${RED}$backup_count${NC}"
    fi
    
    echo ""
    
    # Confirmación
    if [ "$FORCE" != true ]; then
        read -p "¿Estás seguro de que deseas continuar? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo -e "${YELLOW}❌ Operación cancelada${NC}"
            return 0
        fi
        echo ""
    fi
    
    # Backup si se solicita
    if [ "$BACKUP_BEFORE" = true ]; then
        backup_before_remove "$app_name"
    fi
    
    cd "$app_dir"
    
    # Detener y eliminar contenedores
    echo -e "${YELLOW}🛑 Deteniendo y eliminando contenedores...${NC}"
    if [ "$KEEP_VOLUMES" = true ]; then
        docker-compose down
    else
        docker-compose down -v
    fi
    echo -e "${GREEN}✓ Contenedores eliminados${NC}"
    
    # Eliminar volúmenes manualmente si no se mantienen
    if [ "$KEEP_VOLUMES" != true ] && [ -n "$volumes" ]; then
        echo -e "${YELLOW}🗑️  Eliminando volúmenes...${NC}"
        
        for volume in $volumes; do
            if docker volume ls | grep -q "$volume"; then
                docker volume rm "$volume" 2>/dev/null || echo -e "${YELLOW}  ⚠️  No se pudo eliminar $volume${NC}"
            fi
        done
        
        echo -e "${GREEN}✓ Volúmenes eliminados${NC}"
    fi
    
    cd - > /dev/null
    
    # Eliminar directorio
    echo -e "${YELLOW}📁 Eliminando directorio...${NC}"
    rm -rf "$app_dir"
    echo -e "${GREEN}✓ Directorio eliminado${NC}"
    
    # Eliminar backups si se solicita
    if [ "$PURGE_BACKUPS" = true ]; then
        echo -e "${YELLOW}🗑️  Eliminando backups...${NC}"
        find "$BACKUP_DIR" -name "${app_name}_*" -delete 2>/dev/null || true
        echo -e "${GREEN}✓ Backups eliminados${NC}"
    fi
    
    # Actualizar archivo de credenciales
    if [ -f "./credentials.txt" ]; then
        echo -e "${YELLOW}📝 Actualizando archivo de credenciales...${NC}"
        sed -i "/^========================================$/,/^========================================$/{ /${app_name}/,/^========================================$/d; }" ./credentials.txt 2>/dev/null || true
        echo -e "${GREEN}✓ Credenciales actualizadas${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ $app_name eliminado correctamente${NC}"
    
    # Mostrar información de recuperación
    if [ "$KEEP_VOLUMES" = true ]; then
        echo ""
        echo -e "${CYAN}ℹ️  Los volúmenes se mantuvieron. Para recuperar:${NC}"
        echo -e "   1. Reinstala la app con el mismo nombre"
        echo -e "   2. Los datos se conectarán automáticamente"
    elif [ "$BACKUP_BEFORE" = true ]; then
        echo ""
        echo -e "${CYAN}ℹ️  Backup disponible. Para restaurar:${NC}"
        echo -e "   ${YELLOW}./scripts/restore.sh $app_name <backup-file>${NC}"
    fi
    
    echo ""
}

# Eliminar todas las apps
remove_all() {
    echo -e "${RED}⚠️  ADVERTENCIA: Esto eliminará TODAS las aplicaciones${NC}"
    echo ""
    
    if [ "$FORCE" != true ]; then
        read -p "¿Estás absolutamente seguro? (escribe 'SI' para confirmar): " confirm
        
        if [ "$confirm" != "SI" ]; then
            echo -e "${YELLOW}❌ Operación cancelada${NC}"
            return 0
        fi
        echo ""
    fi
    
    local count=0
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            remove_app "$(basename $app_dir)"
            ((count++))
        fi
    done
    
    echo -e "${GREEN}✅ $count aplicaciones eliminadas${NC}"
}

# ============================================
# MAIN
# ============================================

# Variables
BACKUP_BEFORE=false
KEEP_VOLUMES=false
FORCE=false
PURGE_BACKUPS=false
REMOVE_ALL=false
APP_NAME=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup)
            BACKUP_BEFORE=true
            shift
            ;;
        -v|--keep-volumes)
            KEEP_VOLUMES=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -p|--purge)
            PURGE_BACKUPS=true
            shift
            ;;
        -a|--all)
            REMOVE_ALL=true
            shift
            ;;
        -l|--list)
            list_apps
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            APP_NAME=$1
            shift
            ;;
    esac
done

# Validar argumentos
if [ "$REMOVE_ALL" = true ]; then
    remove_all
elif [ -n "$APP_NAME" ]; then
    remove_app "$APP_NAME"
else
    show_help
    exit 1
fi

echo -e "${GREEN}✨ Proceso completado${NC}"
echo ""