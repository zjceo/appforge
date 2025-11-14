#!/bin/bash

# ============================================
# APPFORGE - Script de Restauración
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directorios
APPS_DIR="./apps"
BACKUP_DIR="./backups"

# Función de ayuda
show_help() {
    echo -e "${BLUE}Uso:${NC} $0 <app-name> <backup-file>"
    echo ""
    echo "Opciones:"
    echo "  -l, --list          Listar backups disponibles"
    echo "  -d, --database      Solo restaurar base de datos"
    echo "  -v, --volumes       Solo restaurar volúmenes"
    echo "  -f, --force         No pedir confirmación"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 n8n-1 backups/n8n-1_db_20241113.sql"
    echo "  $0 -d nocodb-1 backups/nocodb-1_db_20241113.sql"
    echo "  $0 -l                                        # Listar backups"
}

# Listar backups
list_backups() {
    echo -e "${BLUE}📋 Backups disponibles:${NC}"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No hay backups disponibles${NC}"
        return
    fi
    
    echo -e "${CYAN}App             Tipo        Fecha                Tamaño${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    for file in "$BACKUP_DIR"/*; do
        if [ -f "$file" ]; then
            local filename=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            local date=$(date -r "$file" '+%Y-%m-%d %H:%M:%S')
            
            # Detectar tipo
            local type="Config"
            if [[ "$filename" == *"_db_"* ]]; then
                type="Database"
            elif [[ "$filename" == *"_data"* ]] || [[ "$filename" == *"_volume"* ]]; then
                type="Volume"
            fi
            
            # Extraer nombre de app
            local app_name=$(echo "$filename" | sed 's/_db_.*//;s/_config_.*//;s/_.*_[0-9]*\..*$//')
            
            printf "%-15s %-10s  %-19s  %8s\n" "$app_name" "$type" "$date" "$size"
        fi
    done
    
    echo ""
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo -e "${CYAN}Total: $total_size${NC}"
}

# Restaurar base de datos
restore_database() {
    local app_dir=$1
    local backup_file=$2
    local app_name=$(basename "$app_dir")
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Archivo de backup no encontrado: $backup_file${NC}"
        return 1
    fi
    
    cd "$app_dir"
    
    echo -e "${YELLOW}  → Restaurando base de datos...${NC}"
    
    # Detectar tipo de base de datos
    if docker-compose ps | grep -q "postgres"; then
        echo -e "${YELLOW}    • PostgreSQL detectado${NC}"
        
        local container=$(docker-compose ps -q postgres 2>/dev/null | head -n1)
        if [ -z "$container" ]; then
            echo -e "${RED}    ❌ Contenedor de PostgreSQL no encontrado${NC}"
            cd - > /dev/null
            return 1
        fi
        
        # Obtener variables
        local db_name=$(grep "POSTGRES_DB=" .env 2>/dev/null | cut -d'=' -f2 || echo "postgres")
        local db_user=$(grep "POSTGRES_USER=" .env 2>/dev/null | cut -d'=' -f2 || echo "postgres")
        
        # Detener app principal (no la BD)
        echo -e "${YELLOW}    • Deteniendo aplicación...${NC}"
        local main_service=$(docker-compose ps --services | grep -v postgres | grep -v redis | head -n1)
        if [ -n "$main_service" ]; then
            docker-compose stop "$main_service" 2>/dev/null || true
        fi
        
        # Limpiar BD
        echo -e "${YELLOW}    • Limpiando base de datos...${NC}"
        docker-compose exec -T postgres psql -U "$db_user" -d "$db_name" -c "DROP SCHEMA public CASCADE;" 2>/dev/null || true
        docker-compose exec -T postgres psql -U "$db_user" -d "$db_name" -c "CREATE SCHEMA public;" 2>/dev/null || true
        
        # Restaurar
        echo -e "${YELLOW}    • Restaurando datos...${NC}"
        cat "$backup_file" | docker-compose exec -T postgres psql -U "$db_user" -d "$db_name"
        
        # Reiniciar app
        echo -e "${YELLOW}    • Reiniciando aplicación...${NC}"
        docker-compose up -d
        
        echo -e "${GREEN}  ✓ Base de datos restaurada${NC}"
        
    elif docker-compose ps | grep -q "mongodb"; then
        echo -e "${YELLOW}    • MongoDB detectado${NC}"
        
        local container=$(docker-compose ps -q mongodb 2>/dev/null | head -n1)
        if [ -z "$container" ]; then
            echo -e "${RED}    ❌ Contenedor de MongoDB no encontrado${NC}"
            cd - > /dev/null
            return 1
        fi
        
        echo -e "${YELLOW}    • Restaurando MongoDB...${NC}"
        docker-compose exec -T mongodb mongorestore --archive < "$backup_file"
        
        echo -e "${GREEN}  ✓ Base de datos restaurada${NC}"
    else
        echo -e "${YELLOW}  ⚠️  No se detectó base de datos${NC}"
    fi
    
    cd - > /dev/null
}

# Restaurar volúmenes
restore_volumes() {
    local app_dir=$1
    local backup_pattern=$2
    local app_name=$(basename "$app_dir")
    
    cd "$app_dir"
    
    echo -e "${YELLOW}  → Restaurando volúmenes...${NC}"
    
    # Detener todos los servicios
    echo -e "${YELLOW}    • Deteniendo servicios...${NC}"
    docker-compose down
    
    # Buscar backups de volúmenes
    local volume_backups=$(find "../$BACKUP_DIR" -name "${app_name}_*_*.tar.gz" ! -name "*_config_*" 2>/dev/null)
    
    if [ -z "$volume_backups" ]; then
        echo -e "${YELLOW}  ⚠️  No se encontraron backups de volúmenes${NC}"
        cd - > /dev/null
        return
    fi
    
    # Restaurar cada volumen
    for backup_file in $volume_backups; do
        local volume_name=$(basename "$backup_file" | sed 's/_[0-9]*\.tar\.gz$//')
        
        echo -e "${YELLOW}    • Restaurando $(basename $backup_file)...${NC}"
        
        # Verificar si el volumen existe
        if docker volume ls | grep -q "$volume_name"; then
            docker run --rm \
                -v "$volume_name:/data" \
                -v "$(pwd)/../$BACKUP_DIR:/backup:ro" \
                alpine:latest \
                sh -c "rm -rf /data/* && tar xzf /backup/$(basename $backup_file) -C /data" 2>/dev/null || true
            
            echo -e "${GREEN}      ✓ $(basename $backup_file) restaurado${NC}"
        else
            echo -e "${YELLOW}      ⚠️  Volumen $volume_name no existe, saltando...${NC}"
        fi
    done
    
    # Reiniciar servicios
    echo -e "${YELLOW}    • Reiniciando servicios...${NC}"
    docker-compose up -d
    
    echo -e "${GREEN}  ✓ Volúmenes restaurados${NC}"
    
    cd - > /dev/null
}

# Restaurar configuración
restore_config() {
    local app_name=$1
    local backup_file=$2
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}❌ Archivo de configuración no encontrado: $backup_file${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}  → Restaurando configuración...${NC}"
    
    # Extraer backup
    tar xzf "$backup_file" -C "$APPS_DIR" 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Configuración restaurada${NC}"
}

# Restaurar app completa
restore_app() {
    local app_name=$1
    local backup_file=$2
    local app_dir="$APPS_DIR/$app_name"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📥 Restaurando $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Verificar que existe el directorio
    if [ ! -d "$app_dir" ]; then
        echo -e "${YELLOW}⚠️  El directorio $app_dir no existe${NC}"
        echo -e "${YELLOW}   Creando desde backup de configuración...${NC}"
        
        # Buscar backup de configuración
        local config_backup=$(find "$BACKUP_DIR" -name "${app_name}_config_*.tar.gz" | sort -r | head -n1)
        if [ -n "$config_backup" ]; then
            restore_config "$app_name" "$config_backup"
        else
            echo -e "${RED}❌ No se encontró backup de configuración para $app_name${NC}"
            return 1
        fi
    fi
    
    # Advertencia
    if [ "$FORCE" != true ]; then
        echo -e "${RED}⚠️  ADVERTENCIA${NC}"
        echo -e "${YELLOW}Esta acción sobrescribirá los datos actuales de $app_name${NC}"
        echo ""
        read -p "¿Deseas continuar? (y/n): " confirm
        
        if [ "$confirm" != "y" ]; then
            echo -e "${YELLOW}❌ Operación cancelada${NC}"
            return 0
        fi
        echo ""
    fi
    
    # Restaurar según tipo
    if [ "$DB_ONLY" = true ]; then
        restore_database "$app_dir" "$backup_file"
    elif [ "$VOLUMES_ONLY" = true ]; then
        restore_volumes "$app_dir" "$backup_file"
    else
        # Restaurar todo
        if [[ "$backup_file" == *"_db_"* ]]; then
            restore_database "$app_dir" "$backup_file"
        fi
        
        restore_volumes "$app_dir" ""
    fi
    
    echo ""
    echo -e "${GREEN}✅ Restauración completada${NC}"
    echo ""
    echo -e "${CYAN}Próximos pasos:${NC}"
    echo -e "  1. Verifica que la aplicación funciona correctamente"
    echo -e "  2. Revisa los logs: ${YELLOW}cd $app_dir && docker-compose logs -f${NC}"
    echo -e "  3. Accede a la aplicación y verifica los datos"
    echo ""
}

# ============================================
# MAIN
# ============================================

# Variables
DB_ONLY=false
VOLUMES_ONLY=false
FORCE=false
APP_NAME=""
BACKUP_FILE=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            list_backups
            exit 0
            ;;
        -d|--database)
            DB_ONLY=true
            shift
            ;;
        -v|--volumes)
            VOLUMES_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$APP_NAME" ]; then
                APP_NAME=$1
            elif [ -z "$BACKUP_FILE" ]; then
                BACKUP_FILE=$1
            fi
            shift
            ;;
    esac
done

# Validar argumentos
if [ -z "$APP_NAME" ]; then
    show_help
    exit 1
fi

if [ -z "$BACKUP_FILE" ] && [ "$DB_ONLY" = true ]; then
    echo -e "${RED}❌ Debes especificar un archivo de backup${NC}"
    exit 1
fi

# Ejecutar restauración
restore_app "$APP_NAME" "$BACKUP_FILE"

echo -e "${GREEN}✨ Proceso completado${NC}"
echo ""