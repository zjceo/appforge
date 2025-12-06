#!/bin/bash

# ============================================
# APPFORGE - Monitor de Salud de Servicios
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

APPS_DIR="./apps"

banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║          AppForge - Monitor de Salud                     ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

check_app_health() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    
    if [ ! -d "$app_dir" ]; then
        return 1
    fi
    
    cd "$app_dir"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🏥 $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local services=$(docker-compose ps --services 2>/dev/null)
    
    printf "  %-25s %-12s %-15s %s\n" "Servicio" "Estado" "Health" "Detalles"
    echo "  ────────────────────────────────────────────────────────────────────"
    
    for service in $services; do
        local container=$(docker-compose ps -q "$service" 2>/dev/null | head -n1)
        
        if [ -z "$container" ]; then
            printf "  %-25s ${RED}%-12s${NC}\n" "$service" "No corriendo"
            continue
        fi
        
        # Estado del contenedor
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        
        # Health status
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "$container" 2>/dev/null)
        
        # Último check
        local last_check=""
        if [ "$health" != "N/A" ]; then
            last_check=$(docker inspect --format='{{if .State.Health}}{{(index .State.Health.Log 0).ExitCode}}{{end}}' "$container" 2>/dev/null)
        fi
        
        # Colorear según estado
        local status_color=$GREEN
        local health_color=$GREEN
        
        case $status in
            running) status_color=$GREEN ;;
            restarting) status_color=$YELLOW ;;
            *) status_color=$RED ;;
        esac
        
        case $health in
            healthy) health_color=$GREEN ;;
            unhealthy) health_color=$RED ;;
            starting) health_color=$YELLOW ;;
        esac
        
        # Mostrar información
        printf "  %-25s ${status_color}%-12s${NC} ${health_color}%-15s${NC}" "$service" "$status" "$health"
        
        # Detalles adicionales
        if [ "$health" = "unhealthy" ]; then
            echo -e "${RED}Check failed (code: $last_check)${NC}"
        elif [ "$health" = "starting" ]; then
            echo -e "${YELLOW}Iniciando...${NC}"
        else
            # Uptime
            local started=$(docker inspect --format='{{.State.StartedAt}}' "$container" 2>/dev/null)
            local uptime=$(date -d "$started" +'%Y-%m-%d %H:%M' 2>/dev/null || echo "N/A")
            echo -e "Up desde: $uptime"
        fi
    done
    
    echo ""
    
    # Logs de healthcheck si hay problemas
    local unhealthy=$(docker-compose ps -q 2>/dev/null | while read container; do
        docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null | grep -q "unhealthy" && echo "$container"
    done)
    
    if [ -n "$unhealthy" ]; then
        echo -e "${YELLOW}⚠️  Contenedores con problemas:${NC}"
        echo ""
        
        for container in $unhealthy; do
            local service=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
            echo -e "  ${RED}●${NC} $service - Últimos logs de health:"
            docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' "$container" 2>/dev/null | tail -n 3 | sed 's/^/    /'
            echo ""
        done
    fi
    
    cd - > /dev/null
}

check_all_apps() {
    banner
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}No hay aplicaciones instaladas${NC}"
        return
    fi
    
    # Resumen general
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Resumen General${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local total_apps=0
    local healthy_apps=0
    local unhealthy_apps=0
    local stopped_apps=0
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            ((total_apps++))
            
            cd "$app_dir"
            
            local containers=$(docker-compose ps -q 2>/dev/null)
            
            if [ -z "$containers" ]; then
                ((stopped_apps++))
            else
                local unhealthy=false
                for container in $containers; do
                    local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}running{{end}}' "$container" 2>/dev/null)
                    if [ "$health" = "unhealthy" ]; then
                        unhealthy=true
                        break
                    fi
                done
                
                if [ "$unhealthy" = true ]; then
                    ((unhealthy_apps++))
                else
                    ((healthy_apps++))
                fi
            fi
            
            cd - > /dev/null
        fi
    done
    
    echo -e "  Total de apps: ${CYAN}$total_apps${NC}"
    echo -e "  Saludables: ${GREEN}$healthy_apps${NC}"
    echo -e "  Con problemas: ${RED}$unhealthy_apps${NC}"
    echo -e "  Detenidas: ${YELLOW}$stopped_apps${NC}"
    echo ""
    
    # Detalle por app
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            check_app_health "$(basename $app_dir)"
        fi
    done
}

watch_mode() {
    while true; do
        check_all_apps
        echo -e "${CYAN}Actualizando cada 10 segundos... (Ctrl+C para salir)${NC}"
        sleep 10
    done
}

# ============================================
# MAIN
# ============================================

case "${1:-}" in
    -w|--watch)
        watch_mode
        ;;
    -h|--help)
        echo "Uso: $0 [opciones] [app-name]"
        echo ""
        echo "Opciones:"
        echo "  -w, --watch     Modo watch (actualización continua)"
        echo "  -h, --help      Mostrar ayuda"
        echo ""
        echo "Ejemplos:"
        echo "  $0              # Ver salud de todas las apps"
        echo "  $0 n8n-1        # Ver salud de n8n-1"
        echo "  $0 -w           # Modo watch"
        ;;
    "")
        check_all_apps
        ;;
    *)
        banner
        check_app_health "$1"
        ;;
esac
