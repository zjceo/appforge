#!/bin/bash

# ============================================
# APPFORGE - Script de Renovación SSL
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
PROXY_DIR="./proxy"
CERTS_DIR="./proxy/traefik"

# Función de ayuda
show_help() {
    echo -e "${BLUE}Uso:${NC} $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  -c, --check         Verificar certificados próximos a vencer"
    echo "  -f, --force         Forzar renovación de todos los certificados"
    echo "  -t, --test          Modo test (dry-run)"
    echo "  -h, --help          Mostrar esta ayuda"
    echo ""
    echo "Descripción:"
    echo "  Este script gestiona la renovación automática de certificados SSL"
    echo "  con Let's Encrypt a través de Traefik."
    echo ""
    echo "Ejemplos:"
    echo "  $0 -c               # Verificar estado de certificados"
    echo "  $0                  # Renovar certificados que lo necesiten"
    echo "  $0 -f               # Forzar renovación de todos"
}

# Verificar que Traefik está corriendo
check_traefik() {
    if ! docker ps | grep -q "traefik"; then
        echo -e "${RED}❌ Traefik no está corriendo${NC}"
        echo -e "${YELLOW}   Inicia Traefik con: cd proxy && docker-compose up -d${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Traefik está corriendo${NC}"
}

# Verificar certificados
check_certificates() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔐 Estado de Certificados SSL${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$CERTS_DIR/acme.json" ]; then
        echo -e "${YELLOW}⚠️  No se encontró acme.json${NC}"
        echo -e "${YELLOW}   Los certificados se generarán automáticamente al acceder a los dominios${NC}"
        return
    fi
    
    # Leer certificados de acme.json
    local cert_count=$(docker exec traefik cat /letsencrypt/acme.json 2>/dev/null | jq -r '.letsencrypt.Certificates | length' 2>/dev/null || echo "0")
    
    if [ "$cert_count" = "0" ]; then
        echo -e "${YELLOW}⚠️  No hay certificados almacenados${NC}"
        return
    fi
    
    echo -e "${GREEN}✓ $cert_count certificado(s) encontrado(s)${NC}"
    echo ""
    
    printf "  %-40s %-20s %s\n" "Dominio" "Expira" "Estado"
    echo "  ────────────────────────────────────────────────────────────────────────────"
    
    # Extraer y mostrar información de certificados
    docker exec traefik cat /letsencrypt/acme.json 2>/dev/null | \
    jq -r '.letsencrypt.Certificates[] | .domain.main + "," + (.certificate | @base64d)' 2>/dev/null | \
    while IFS=',' read -r domain cert_data; do
        # Extraer fecha de expiración del certificado
        local expiry=$(echo "$cert_data" | openssl x509 -noout -enddate 2>/dev/null | cut -d'=' -f2)
        
        if [ -n "$expiry" ]; then
            local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
            local now_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            
            local status_icon="✅"
            local status_color=$GREEN
            local status_text="OK"
            
            if [ "$days_left" -lt 30 ]; then
                status_icon="⚠️"
                status_color=$YELLOW
                status_text="Renovar pronto"
            fi
            
            if [ "$days_left" -lt 7 ]; then
                status_icon="❌"
                status_color=$RED
                status_text="Renovar urgente"
            fi
            
            printf "  ${status_color}${status_icon}${NC} %-37s %-20s ${status_color}%s${NC} (${days_left}d)\n" \
                "$domain" "$(date -d "$expiry" '+%Y-%m-%d %H:%M')" "$status_text"
        fi
    done
    
    echo ""
}

# Renovar certificados
renew_certificates() {
    local force=$1
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔄 Renovando Certificados${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$CERTS_DIR/acme.json" ]; then
        echo -e "${YELLOW}⚠️  No hay certificados para renovar${NC}"
        echo -e "${CYAN}ℹ️  Los certificados se generarán automáticamente cuando accedas a tus dominios${NC}"
        return
    fi
    
    # Traefik renueva automáticamente los certificados
    # Solo necesitamos reiniciarlo si queremos forzar
    if [ "$force" = true ]; then
        echo -e "${YELLOW}  → Forzando renovación...${NC}"
        
        # Backup del acme.json actual
        local backup_file="$CERTS_DIR/acme.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CERTS_DIR/acme.json" "$backup_file"
        echo -e "${GREEN}  ✓ Backup creado: $(basename $backup_file)${NC}"
        
        # Reiniciar Traefik para forzar renovación
        cd "$PROXY_DIR"
        docker-compose restart traefik
        cd - > /dev/null
        
        echo -e "${YELLOW}  → Esperando a que Traefik reinicie...${NC}"
        sleep 10
        
        echo -e "${GREEN}  ✓ Traefik reiniciado${NC}"
    else
        echo -e "${CYAN}ℹ️  Traefik renueva automáticamente los certificados 30 días antes de expirar${NC}"
        echo -e "${CYAN}   No es necesario renovar manualmente${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Proceso de renovación completado${NC}"
    echo ""
}

# Verificar configuración de Traefik
check_traefik_config() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}⚙️  Configuración de Traefik${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if [ ! -f "$PROXY_DIR/traefik.yml" ]; then
        echo -e "${RED}❌ No se encontró traefik.yml${NC}"
        return
    fi
    
    # Leer configuración
    local email=$(grep "email:" "$PROXY_DIR/traefik.yml" | awk '{print $2}')
    local storage=$(grep "storage:" "$PROXY_DIR/traefik.yml" | awk '{print $2}')
    
    echo -e "  Email Let's Encrypt: ${CYAN}$email${NC}"
    echo -e "  Archivo de certs: ${CYAN}$storage${NC}"
    
    # Verificar archivo acme.json
    if [ -f "$CERTS_DIR/acme.json" ]; then
        local size=$(du -h "$CERTS_DIR/acme.json" | cut -f1)
        local perms=$(stat -c %a "$CERTS_DIR/acme.json" 2>/dev/null || stat -f %A "$CERTS_DIR/acme.json" 2>/dev/null)
        
        echo -e "  Tamaño acme.json: ${CYAN}$size${NC}"
        echo -e "  Permisos: ${CYAN}$perms${NC}"
        
        if [ "$perms" != "600" ]; then
            echo -e "${YELLOW}  ⚠️  Los permisos deberían ser 600${NC}"
            read -p "  ¿Corregir permisos? (y/n): " fix_perms
            if [ "$fix_perms" = "y" ]; then
                chmod 600 "$CERTS_DIR/acme.json"
                echo -e "${GREEN}  ✓ Permisos corregidos${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠️  acme.json no existe aún${NC}"
    fi
    
    echo ""
}

# Ver logs de Traefik
show_traefik_logs() {
    echo -e "${CYAN}📋 Logs de Traefik (últimas 50 líneas)${NC}"
    echo ""
    
    cd "$PROXY_DIR"
    docker-compose logs --tail=50 traefik | grep -i "certificate\|acme\|letsencrypt" || \
    docker-compose logs --tail=50 traefik
    cd - > /dev/null
}

# Modo test (dry-run)
test_mode() {
    echo -e "${YELLOW}🧪 Modo Test - Simulando renovación${NC}"
    echo ""
    
    check_traefik
    check_traefik_config
    check_certificates
    
    echo -e "${CYAN}ℹ️  Este fue un modo de prueba. No se realizaron cambios.${NC}"
    echo ""
}

# ============================================
# MAIN
# ============================================

# Variables
CHECK_ONLY=false
FORCE_RENEW=false
TEST_MODE=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE_RENEW=true
            shift
            ;;
        -t|--test)
            TEST_MODE=true
            shift
            ;;
        -l|--logs)
            show_traefik_logs
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción desconocida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║          AppForge - Gestión de Certificados SSL         ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Ejecutar
if [ "$TEST_MODE" = true ]; then
    test_mode
elif [ "$CHECK_ONLY" = true ]; then
    check_traefik
    check_traefik_config
    check_certificates
else
    check_traefik
    check_certificates
    renew_certificates "$FORCE_RENEW"
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}ℹ️  Información Adicional${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  • Traefik renueva automáticamente los certificados"
echo -e "  • La renovación ocurre 30 días antes de expirar"
echo -e "  • Los certificados tienen una validez de 90 días"
echo -e "  • Para ver logs: ${YELLOW}$0 -l${NC}"
echo ""
echo -e "${GREEN}✨ Proceso completado${NC}"
echo ""