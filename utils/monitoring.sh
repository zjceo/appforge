#!/bin/bash

# ============================================
# APPFORGE - Script de Monitoreo
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

# Función de ayuda
show_help() {
    echo -e "${BLUE}Uso:${NC} $0 [opciones] [app-name]"
    echo ""
    echo "Opciones:"
    echo "  -a, --all           Monitorear todas las aplicaciones"
    echo "  -l, --logs          Mostrar logs en tiempo real"
    echo "  -s, --stats         Mostrar estadísticas detalladas"
    echo "  -w, --watch         Modo watch (actualización continua)"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0                  # Estado general de todas las apps"
    echo "  $0 n8n-1            # Estado detallado de n8n-1"
    echo "  $0 -l n8n-1         # Ver logs de n8n-1"
    echo "  $0 -w               # Monitoreo continuo"
}

# Banner
banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║          AppForge - Monitor de Aplicaciones             ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Estado general del sistema
system_overview() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🖥️  Estado del Sistema${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo -e "  CPU: ${CYAN}${cpu_usage}%${NC}"
    
    # Memoria
    local mem_info=$(free -h | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100}')
    echo -e "  RAM: ${CYAN}${mem_used}${NC} / ${mem_total} (${mem_percent}%)"
    
    # Disco
    local disk_info=$(df -h / | tail -1)
    local disk_used=$(echo $disk_info | awk '{print $3}')
    local disk_total=$(echo $disk_info | awk '{print $2}')
    local disk_percent=$(echo $disk_info | awk '{print $5}')
    echo -e "  Disco: ${CYAN}${disk_used}${NC} / ${disk_total} (${disk_percent})"
    
    # Docker
    local containers_running=$(docker ps -q | wc -l)
    local containers_total=$(docker ps -a -q | wc -l)
    local images_count=$(docker images -q | wc -l)
    local volumes_count=$(docker volume ls -q | wc -l)
    
    echo ""
    echo -e "  Contenedores: ${GREEN}${containers_running}${NC} / ${containers_total}"
    echo -e "  Imágenes: ${CYAN}${images_count}${NC}"
    echo -e "  Volúmenes: ${CYAN}${volumes_count}${NC}"
    
    echo ""
}

# Estado de una aplicación específica
app_status() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    
    if [ ! -d "$app_dir" ]; then
        echo -e "${RED}❌ El directorio $app_dir no existe${NC}"
        return 1
    fi
    
    cd "$app_dir"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 $app_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Estado de servicios
    echo -e "\n${YELLOW}Servicios:${NC}"
    echo ""
    
    local services=$(docker-compose ps --services 2>/dev/null)
    
    for service in $services; do
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null | head -n1)
        
        if [ -n "$container_id" ]; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null)
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "N/A")
            local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$container_id" 2>/dev/null | xargs -I {} date -d {} +'%Y-%m-%d %H:%M:%S')
            
            local status_icon="⏸️"
            local status_color=$YELLOW
            
            case $status in
                running)
                    status_icon="✅"
                    status_color=$GREEN
                    ;;
                exited)
                    status_icon="❌"
                    status_color=$RED
                    ;;
                restarting)
                    status_icon="🔄"
                    status_color=$YELLOW
                    ;;
            esac
            
            printf "  ${status_color}${status_icon}${NC} %-20s ${status_color}%-10s${NC}" "$service" "$status"
            
            if [ "$health" != "N/A" ]; then
                case $health in
                    healthy)
                        echo -e " ${GREEN}●${NC} healthy"
                        ;;
                    unhealthy)
                        echo -e " ${RED}●${NC} unhealthy"
                        ;;
                    starting)
                        echo -e " ${YELLOW}●${NC} starting"
                        ;;
                esac
            else
                echo ""
            fi
        else
            printf "  ${RED}❌${NC} %-20s ${RED}%-10s${NC}\n" "$service" "stopped"
        fi
    done
    
    # Recursos
    echo ""
    echo -e "${YELLOW}Recursos:${NC}"
    echo ""
    
    local containers=$(docker-compose ps -q 2>/dev/null)
    
    if [ -n "$containers" ]; then
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $containers | \
        awk 'NR==1 {printf "  %-30s %-10s %-20s %-15s %s\n", $1, $2, $3" "$4, $5" "$6, $7" "$8}
             NR>1  {printf "  %-30s %-10s %-20s %-15s %s\n", $1, $2, $3" "$4, $5" "$6, $7" "$8}'
    else
        echo -e "  ${YELLOW}No hay contenedores en ejecución${NC}"
    fi
    
    # Volúmenes
    echo ""
    echo -e "${YELLOW}Volúmenes:${NC}"
    echo ""
    
    local volumes=$(docker-compose config --volumes 2>/dev/null)
    
    if [ -n "$volumes" ]; then
        for volume in $volumes; do
            if docker volume ls | grep -q "$volume"; then
                local size=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "N/A")
                printf "  ${CYAN}●${NC} %-40s %s\n" "$volume" "$size"
            fi
        done
    else
        echo -e "  ${YELLOW}No hay volúmenes configurados${NC}"
    fi
    
    # URLs de acceso
    if [ -f ".env" ]; then
        local domain=$(grep "^DOMAIN=" .env 2>/dev/null | cut -d'=' -f2)
        if [ -n "$domain" ]; then
            echo ""
            echo -e "${YELLOW}Acceso:${NC}"
            echo -e "  🌐 https://$domain"
        fi
    fi
    
    cd - > /dev/null
    echo ""
}

# Estado de todas las apps
all_apps_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📦 Aplicaciones Instaladas${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No hay aplicaciones instaladas${NC}"
        echo ""
        return
    fi
    
    printf "  %-20s %-15s %-10s %-10s %s\n" "Aplicación" "Estado" "CPU" "Memoria" "Uptime"
    echo "  ────────────────────────────────────────────────────────────────────"
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            local app_name=$(basename "$app_dir")
            
            cd "$app_dir"
            
            # Obtener contenedor principal
            local main_container=$(docker-compose ps -q 2>/dev/null | head -n1)
            
            if [ -n "$main_container" ]; then
                local status=$(docker inspect --format='{{.State.Status}}' "$main_container" 2>/dev/null)
                local cpu=$(docker stats --no-stream --format "{{.CPUPerc}}" "$main_container" 2>/dev/null)
                local mem=$(docker stats --no-stream --format "{{.MemUsage}}" "$main_container" 2>/dev/null | awk '{print $1}')
                local uptime=$(docker inspect --format='{{.State.StartedAt}}' "$main_container" 2>/dev/null | xargs -I {} date -d {} +%s)
                local now=$(date +%s)
                local diff=$((now - uptime))
                local hours=$((diff / 3600))
                local minutes=$(( (diff % 3600) / 60 ))
                
                local status_icon="⏸️"
                local status_color=$YELLOW
                
                case $status in
                    running)
                        status_icon="✅"
                        status_color=$GREEN
                        ;;
                    exited)
                        status_icon="❌"
                        status_color=$RED
                        ;;
                esac
                
                printf "  ${status_color}${status_icon}${NC} %-17s %-15s %-10s %-10s %sh %sm\n" \
                    "$app_name" "$status" "$cpu" "$mem" "$hours" "$minutes"
            else
                printf "  ${RED}❌${NC} %-17s %-15s\n" "$app_name" "stopped"
            fi
            
            cd - > /dev/null
        fi
    done
    
    echo ""
}

# Ver logs en tiempo real
show_logs() {
    local app_name=$1
    local app_dir="$APPS_DIR/$app_name"
    
    if [ ! -d "$app_dir" ]; then
        echo -e "${RED}❌ El directorio $app_dir no existe${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Mostrando logs de $app_name (Ctrl+C para salir)${NC}"
    echo ""
    
    cd "$app_dir"
    docker-compose logs -f --tail=100
    cd - > /dev/null
}

# Modo watch
watch_mode() {
    while true; do
        banner
        system_overview
        all_apps_status
        echo -e "${CYAN}  Actualizando cada 5 segundos... (Ctrl+C para salir)${NC}"
        sleep 5
    done
}

# ============================================
# MAIN
# ============================================

# Variables
SHOW_LOGS=false
SHOW_STATS=false
WATCH_MODE=false
ALL_APPS=false
APP_NAME=""

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            ALL_APPS=true
            shift
            ;;
        -l|--logs)
            SHOW_LOGS=true
            shift
            ;;
        -s|--stats)
            SHOW_STATS=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
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

# Ejecutar
if [ "$WATCH_MODE" = true ]; then
    watch_mode
elif [ "$SHOW_LOGS" = true ]; then
    if [ -z "$APP_NAME" ]; then
        echo -e "${RED}❌ Debes especificar una aplicación para ver logs${NC}"
        exit 1
    fi
    show_logs "$APP_NAME"
elif [ -n "$APP_NAME" ]; then
    banner
    system_overview
    app_status "$APP_NAME"
else
    banner
    system_overview
    all_apps_status
fi