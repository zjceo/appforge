#!/bin/bash

# ============================================
# APPFORGE - Script de Actualización
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
    echo -e "${BLUE}Uso:${NC} $0 [opciones] [app-name]"
    echo ""
    echo "Opciones:"
    echo "  -a, --all           Actualizar todas las aplicaciones"
    echo "  -b, --backup        Hacer backup antes de actualizar"
    echo "  -f, --force         Forzar recreación de contenedores"
    echo "  -p, --prune         Limpiar imágenes antiguas después"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 n8n-1                    # Actualizar n8n-1"
    echo "  $0 -b n8n-1                 # Actualizar con backup previo"
    echo "  $0 -a                       # Actualizar todas las apps"
    echo "  $0 -a -b -p                 # Todo: backup, update, cleanup"
}

# Verificar actualizaciones disponibles
check_updates() {
    local app_dir=$1
    local app_name=$(basename "$app_dir")
    
    cd "$app_dir"
    
    echo -e "${YELLOW}  → Verificando actualizaciones...${NC}"
    
    local updates=$(docker-compose pull 2>&1 | grep -c "Downloaded newer image" || echo "0")
    
    if [ "$updates" -gt 0 ]; then
        echo -e "${CYAN}    ✓ $updates imagen(es) actualizada(s)${NC}"
        cd - > /dev/null
        return 0
    else
        echo -e "${GREEN}    ✓ Ya está actualizado${NC}"
        cd - > /dev/null
        return 1
    fi
}

# Backup antes de actualizar
backup_before_update() {
    local app_name=$1
    
    echo -e "${YELLOW}  → Creando backup de seguridad...${NC}"
    
    if [ -f "./scripts/backup.sh" ]; then
        ./scripts/backup.sh "$app_name" > /dev/null 2>&1
        echo -e "${GREEN}    ✓ Backup creado${NC}"
    else
        echo -e "${YELLOW}    ⚠️  Script de backup no encontrado${NC}"
    fi
}

# Actualizar una app
update_app() {
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
    echo -e "${BLUE}🔄 Actualizando $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Backup si se solicita
    if [ "$BACKUP_BEFORE" = true ]; then
        backup_before_update "$app_name"
    fi
    
    cd "$app_dir"
    
    # Verificar si hay actualizaciones
    if ! check_updates "$app_dir"; then
        if [ "$FORCE_UPDATE" != true ]; then
            echo ""
            return 0
        fi
    fi
    
    # Detener servicios
    echo -e "${YELLOW}  → Deteniendo servicios...${NC}"
    docker-compose down
    
    # Actualizar imágenes
    echo -e "${YELLOW}  → Descargando nuevas imágenes...${NC}"
    docker-compose pull
    
    # Recrear contenedores
    if [ "$FORCE_UPDATE" = true ]; then
        echo -e "${YELLOW}  → Recreando contenedores (force)...${NC}"
        docker-compose up -d --force-recreate
    else
        echo -e "${YELLOW}  → Iniciando servicios actualizados...${NC}"
        docker-compose up -d
    fi
    
    # Esperar a que levanten los servicios
    echo -e "${YELLOW}  → Esperando inicialización...${NC}"
    sleep 5
    
    # Verificar estado
    local running=$(docker-compose ps | grep -c "Up" || echo "0")
    local total=$(docker-compose ps --services | wc -l)
    
    if [ "$running" -eq "$total" ]; then
        echo -e "${GREEN}  ✓ Todos los servicios corriendo ($running/$total)${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Algunos servicios no iniciaron ($running/$total)${NC}"
        echo -e "${YELLOW}     Revisa los logs: docker-compose logs -f${NC}"
    fi
    
    cd - > /dev/null
    
    echo ""
}

# Actualizar todas las apps
update_all() {
    echo -e "${GREEN}🚀 Actualizando todas las aplicaciones${NC}"
    echo ""
    
    if [ ! -d "$APPS_DIR" ]; then
        echo -e "${RED}❌ No se encontró el directorio de apps${NC}"
        exit 1
    fi
    
    local count=0
    local updated=0
    local failed=0
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            ((count++))
            
            if update_app "$(basename $app_dir)"; then
                ((updated++))
            else
                ((failed++))
            fi
        fi
    done
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Resumen de actualizaciones${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Total de apps: ${CYAN}$count${NC}"
    echo -e "  Actualizadas: ${GREEN}$updated${NC}"
    echo -e "  Fallidas: ${RED}$failed${NC}"
    echo ""
}

# Limpiar imágenes antiguas
cleanup_images() {
    echo -e "${YELLOW}🧹 Limpiando imágenes antiguas...${NC}"
    
    # Imágenes sin usar
    local dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$dangling" -gt 0 ]; then
        docker image prune -f > /dev/null 2>&1
        echo -e "${GREEN}  ✓ $dangling imagen(es) sin usar eliminadas${NC}"
    else
        echo -e "${CYAN}  ✓ No hay imágenes para limpiar${NC}"
    fi
    
    # Contenedores detenidos
    local stopped=$(docker ps -a -f "status=exited" -q | wc -l)
    if [ "$stopped" -gt 0 ]; then
        docker container prune -f > /dev/null 2>&1
        echo -e "${GREEN}  ✓ $stopped contenedor(es) detenidos eliminados${NC}"
    fi
    
    # Volúmenes sin usar
    local volumes=$(docker volume ls -qf dangling=true | wc -l)
    if [ "$volumes" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠️  $volumes volumen(es) sin usar encontrados${NC}"
        read -p "  ¿Eliminar volúmenes sin usar? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            docker volume prune -f > /dev/null 2>&1
            echo -e "${GREEN}  ✓ Volúmenes eliminados${NC}"
        fi
    fi
    
    echo ""
}

# Mostrar versiones actuales
show_versions() {
    echo -e "${BLUE}📦 Versiones instaladas:${NC}"
    echo ""
    
    if [ ! -d "$APPS_DIR" ]; then
        echo -e "${YELLOW}  No hay aplicaciones instaladas${NC}"
        return
    fi
    
    echo -e "${CYAN}App             Servicio              Imagen${NC}"
    echo "─────────────────────────────────────────────────────────────────────"
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            local app_name=$(basename "$app_dir")
            
            cd "$app_dir"
            
            # Obtener servicios
            local services=$(docker-compose ps --services 2>/dev/null)
            
            for service in $services; do
                local container=$(docker-compose ps -q "$service" 2>/dev/null | head -n1)
                
                if [ -n "$container" ]; then
                    local image=$(docker inspect --format='{{.Config.Image}}' "$container" 2>/dev/null)
                    printf "%-15s %-20s  %s\n" "$app_name" "$service" "$image"
                fi
            done
            
            cd - > /dev/null
        fi
    done
    
    echo ""
}

# ============================================
# MAIN
# ============================================

# Variables
ALL_APPS=false
BACKUP_BEFORE=false
FORCE_UPDATE=false
PRUNE_AFTER=false
SHOW_VERSIONS=false
APP_NAME=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            ALL_APPS=true
            shift
            ;;
        -b|--backup)
            BACKUP_BEFORE=true
            shift
            ;;
        -f|--force)
            FORCE_UPDATE=true
            shift
            ;;
        -p|--prune)
            PRUNE_AFTER=true
            shift
            ;;
        -v|--versions)
            show_versions
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

# Ejecutar actualización
if [ "$ALL_APPS" = true ]; then
    update_all
elif [ -n "$APP_NAME" ]; then
    update_app "$APP_NAME"
else
    show_help
    exit 1
fi

# Limpiar si se solicita
if [ "$PRUNE_AFTER" = true ]; then
    cleanup_images
fi

echo -e "${GREEN}✨ Actualización completada${NC}"
echo ""