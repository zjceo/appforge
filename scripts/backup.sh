#!/bin/bash

# ============================================
# APPFORGE - Script de Backup
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo "  -a, --all           Hacer backup de todas las apps"
    echo "  -c, --compress      Comprimir backup"
    echo "  -d, --database      Solo backup de base de datos"
    echo "  -v, --volumes       Solo backup de volúmenes"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 n8n-1                    # Backup completo de n8n-1"
    echo "  $0 -d nocodb-1              # Solo BD de nocodb-1"
    echo "  $0 -a                       # Backup de todas las apps"
}

# Backup de base de datos
backup_database() {
    local app_dir=$1
    local app_name=$(basename "$app_dir")
    local backup_file="$BACKUP_DIR/${app_name}_db_${TIMESTAMP}.sql"
    
    cd "$app_dir"
    
    # Detectar tipo de base de datos
    if docker-compose ps | grep -q "postgres"; then
        echo -e "${YELLOW}  → Backup de PostgreSQL...${NC}"
        
        local container=$(docker-compose ps -q postgres 2>/dev/null | head -n1)
        if [ -n "$container" ]; then
            local db_name=$(docker-compose exec -T postgres env | grep POSTGRES_DB= | cut -d'=' -f2)
            local db_user=$(docker-compose exec -T postgres env | grep POSTGRES_USER= | cut -d'=' -f2)
            
            docker-compose exec -T postgres pg_dump -U "$db_user" "$db_name" > "../$backup_file"
            echo -e "${GREEN}  ✓ BD guardada: $backup_file${NC}"
        fi
        
    elif docker-compose ps | grep -q "mongodb"; then
        echo -e "${YELLOW}  → Backup de MongoDB...${NC}"
        
        local container=$(docker-compose ps -q mongodb 2>/dev/null | head -n1)
        if [ -n "$container" ]; then
            docker-compose exec -T mongodb mongodump --archive > "../$backup_file.archive"
            echo -e "${GREEN}  ✓ BD guardada: $backup_file.archive${NC}"
        fi
    fi
    
    cd - > /dev/null
}

# Backup de volúmenes
backup_volumes() {
    local app_dir=$1
    local app_name=$(basename "$app_dir")
    
    cd "$app_dir"
    
    echo -e "${YELLOW}  → Backup de volúmenes...${NC}"
    
    local volumes=$(docker-compose config --volumes 2>/dev/null)
    
    if [ -z "$volumes" ]; then
        echo -e "${YELLOW}  ⚠️  No se encontraron volúmenes${NC}"
        cd - > /dev/null
        return
    fi
    
    for volume in $volumes; do
        local backup_file="$BACKUP_DIR/${app_name}_${volume}_${TIMESTAMP}.tar.gz"
        echo -e "${YELLOW}    • Backup de $volume...${NC}"
        
        docker run --rm \
            -v "$volume:/data:ro" \
            -v "$(pwd)/../$BACKUP_DIR:/backup" \
            alpine:latest \
            tar czf "/backup/$(basename $backup_file)" -C /data . 2>/dev/null || true
        
        if [ -f "../$backup_file" ]; then
            local size=$(du -h "../$backup_file" | cut -f1)
            echo -e "${GREEN}    ✓ Guardado: $(basename $backup_file) ($size)${NC}"
        fi
    done
    
    cd - > /dev/null
}

# Backup de archivos de configuración
backup_config() {
    local app_dir=$1
    local app_name=$(basename "$app_dir")
    local backup_file="$BACKUP_DIR/${app_name}_config_${TIMESTAMP}.tar.gz"
    
    echo -e "${YELLOW}  → Backup de configuración...${NC}"
    
    tar czf "$backup_file" \
        -C "$(dirname $app_dir)" \
        "$(basename $app_dir)" \
        --exclude="$(basename $app_dir)/node_modules" \
        --exclude="$(basename $app_dir)/.git" \
        2>/dev/null || true
    
    if [ -f "$backup_file" ]; then
        local size=$(du -h "$backup_file" | cut -f1)
        echo -e "${GREEN}  ✓ Config guardada: $(basename $backup_file) ($size)${NC}"
    fi
}

# Backup completo de una app
backup_app() {
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
    echo -e "${BLUE}📦 Backup de $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup según opciones
    if [ "$DB_ONLY" = true ]; then
        backup_database "$app_dir"
    elif [ "$VOLUMES_ONLY" = true ]; then
        backup_volumes "$app_dir"
    else
        backup_database "$app_dir"
        backup_volumes "$app_dir"
        backup_config "$app_dir"
    fi
    
    echo ""
}

# Backup de todas las apps
backup_all() {
    echo -e "${GREEN}🚀 Iniciando backup de todas las aplicaciones${NC}"
    echo ""
    
    if [ ! -d "$APPS_DIR" ]; then
        echo -e "${RED}❌ No se encontró el directorio de apps${NC}"
        exit 1
    fi
    
    local count=0
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            backup_app "$(basename $app_dir)"
            ((count++))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No se encontraron aplicaciones para respaldar${NC}"
    else
        echo -e "${GREEN}✅ Backup completado: $count aplicaciones respaldadas${NC}"
    fi
}

# Listar backups
list_backups() {
    echo -e "${BLUE}📋 Backups disponibles:${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No hay backups disponibles${NC}"
        return
    fi
    
    ls -lh "$BACKUP_DIR" | grep -v "^total" | awk '{
        size = $5
        date = $6 " " $7 " " $8
        file = $9
        printf "  %-40s %10s  %s\n", file, size, date
    }'
    
    echo ""
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo -e "${CYAN}  Total: $total_size${NC}"
}

# Limpiar backups antiguos
clean_old_backups() {
    local days=${1:-30}
    
    echo -e "${YELLOW}🧹 Limpiando backups más antiguos de $days días...${NC}"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}  No hay directorio de backups${NC}"
        return
    fi
    
    local count=$(find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql" -o -name "*.archive" -mtime +$days | wc -l)
    
    if [ $count -gt 0 ]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -o -name "*.sql" -o -name "*.archive" -mtime +$days -delete
        echo -e "${GREEN}  ✓ $count archivos eliminados${NC}"
    else
        echo -e "${YELLOW}  No hay backups antiguos para eliminar${NC}"
    fi
}

# ============================================
# MAIN
# ============================================

# Variables
ALL_APPS=false
DB_ONLY=false
VOLUMES_ONLY=false
APP_NAME=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            ALL_APPS=true
            shift
            ;;
        -d|--database)
            DB_ONLY=true
            shift
            ;;
        -v|--volumes)
            VOLUMES_ONLY=true
            shift
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        -c|--clean)
            clean_old_backups ${2:-30}
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

# Ejecutar backup
if [ "$ALL_APPS" = true ]; then
    backup_all
elif [ -n "$APP_NAME" ]; then
    backup_app "$APP_NAME"
else
    show_help
    exit 1
fi

echo ""
echo -e "${GREEN}✨ Proceso completado${NC}"
echo -e "${CYAN}📁 Backups guardados en: $BACKUP_DIR${NC}"
echo ""