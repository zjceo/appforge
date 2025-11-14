#!/bin/bash

# ============================================
# APPFORGE - Multi-App VPS Installer v2.0
# Repositorio: https://github.com/zjceo/appforge
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

# Variables globales
PATH_INSTALL=$(pwd)
APPS_DIR="$PATH_INSTALL/apps"
TEMPLATES_DIR="$PATH_INSTALL/templates"
CERTS_DIR="$PATH_INSTALL/certs"
PROXY_DIR="$PATH_INSTALL/proxy"
CREDENTIALS_FILE="$PATH_INSTALL/credentials.txt"

# ============================================
# FUNCIONES AUXILIARES
# ============================================

banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║       █████╗ ██████╗ ██████╗ ███████╗ ██████╗ ██████╗  ║
    ║      ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔═══██╗██╔══██╗ ║
    ║      ███████║██████╔╝██████╔╝█████╗  ██║   ██║██████╔╝ ║
    ║      ██╔══██║██╔═══╝ ██╔═══╝ ██╔══╝  ██║   ██║██╔══██╗ ║
    ║      ██║  ██║██║     ██║     ██║     ╚██████╔╝██║  ██║ ║
    ║      ╚═╝  ╚═╝╚═╝     ╚═╝     ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ║
    ║                                                          ║
    ║          Multi-App VPS Installer & Manager v2.0         ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

generate_password() {
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20
}

generate_db_name() {
    local domain=$1
    echo "$domain" | sed 's/\./_/g' | sed 's/-/_/g'
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# VERIFICACIÓN DE DEPENDENCIAS
# ============================================

check_dependencies() {
    echo -e "${YELLOW}Verificando dependencias...${NC}"
    
    local missing_deps=false
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker no está instalado${NC}"
        missing_deps=true
    else
        echo -e "${GREEN}✓ Docker detectado${NC}"
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose no está instalado${NC}"
        missing_deps=true
    else
        echo -e "${GREEN}✓ Docker Compose detectado${NC}"
    fi
    
    if [ "$missing_deps" = true ]; then
        echo ""
        echo -e "${YELLOW}¿Deseas instalar las dependencias faltantes? (s/n)${NC}"
        read -p "> " install_deps
        
        if [ "$install_deps" = "s" ]; then
            install_dependencies
        else
            echo -e "${RED}No se puede continuar sin las dependencias necesarias${NC}"
            exit 1
        fi
    fi
    
    echo ""
}

install_dependencies() {
    echo -e "${YELLOW}Instalando dependencias...${NC}"
    
    # Actualizar sistema
    apt-get -y update
    apt-get -y upgrade
    
    # Instalar utilidades básicas
    apt-get -y install git curl wget gnupg lsb-release ca-certificates
    
    # Instalar Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Instalando Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl start docker
        systemctl enable docker
        rm get-docker.sh
        echo -e "${GREEN}✓ Docker instalado${NC}"
    fi
    
    # Instalar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}Instalando Docker Compose...${NC}"
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo -e "${GREEN}✓ Docker Compose instalado${NC}"
    fi
    
    # Crear red Docker
    docker network create appforge-network 2>/dev/null || true
    
    echo -e "${GREEN}✓ Dependencias instaladas correctamente${NC}"
    echo ""
}

# ============================================
# INSTALACIÓN DEL PROXY (TRAEFIK)
# ============================================

setup_proxy() {
    if [ -f "$PROXY_DIR/docker-compose.yml" ]; then
        echo -e "${GREEN}✓ Proxy ya configurado${NC}"
        return
    fi
    
    echo -e "${YELLOW}Configurando Traefik como proxy inverso...${NC}"
    
    mkdir -p "$PROXY_DIR/traefik"
    
    # Solicitar email para Let's Encrypt
    read -p "Email para certificados SSL (Let's Encrypt): " ssl_email
    [ -z "$ssl_email" ] && ssl_email="admin@example.com"
    
    cat > "$PROXY_DIR/traefik.yml" << EOF
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  letsencrypt:
    acme:
      email: $ssl_email
      storage: /letsencrypt/acme.json
      tlsChallenge: {}

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: appforge-network
EOF

    cat > "$PROXY_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    command:
      - "--configFile=/traefik.yml"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - ./traefik.yml:/traefik.yml:ro
      - ./traefik:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - appforge-network

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=Host(\`portainer.localhost\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
    networks:
      - appforge-network

volumes:
  portainer_data:

networks:
  appforge-network:
    external: true
EOF

    cd "$PROXY_DIR"
    docker-compose up -d
    
    echo -e "${GREEN}✓ Traefik instalado correctamente${NC}"
    echo -e "${CYAN}  Dashboard: http://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo ""
}

# ============================================
# GUARDAR CREDENCIALES
# ============================================

save_credentials() {
    local domain=$1
    local app=$2
    local email=$3
    local password=$4
    local db_password=$5
    local extra_info=$6
    
    cat >> "$CREDENTIALS_FILE" << EOF

========================================
$app - $domain
========================================
URL: https://$domain
Email: $email
Password: $password
DB Password: $db_password
${extra_info}
Instalado: $(date '+%Y-%m-%d %H:%M:%S')
========================================

EOF
    
    chmod 600 "$CREDENTIALS_FILE"
}

# ============================================
# INSTALACIÓN DE APLICACIONES
# ============================================

install_app() {
    local app_name=$1
    local template_dir="$TEMPLATES_DIR/$app_name"
    
    # Verificar que existe el template
    if [ ! -d "$template_dir" ]; then
        echo -e "${RED}❌ Template no encontrado para $app_name${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Instalación de $app_name${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # Solicitar dominio
    while true; do
        read -p "Dominio (ej: $app_name.tudominio.com): " domain
        
        if [ -z "$domain" ]; then
            echo -e "${RED}❌ Debes ingresar un dominio${NC}"
            continue
        fi
        
        if ! validate_domain "$domain"; then
            echo -e "${RED}❌ Dominio inválido. Formato: subdominio.dominio.com${NC}"
            continue
        fi
        
        break
    done
    
    # Solicitar número de servicio
    read -p "Número de servicio (1-99) [1]: " service_num
    [ -z "$service_num" ] && service_num=1
    
    # Crear directorio de instalación
    local app_dir="$APPS_DIR/${app_name}-${service_num}"
    
    if [ -d "$app_dir" ]; then
        echo -e "${YELLOW}⚠️  El directorio $app_dir ya existe${NC}"
        read -p "¿Deseas continuar? (s/n): " confirm
        if [ "$confirm" != "s" ]; then
            return 1
        fi
    fi
    
    mkdir -p "$app_dir"
    
    # Generar credenciales
    local db_name=$(generate_db_name "$domain")_${service_num}
    local db_password=$(generate_password)
    local admin_email="${app_name}@${domain}"
    local admin_password=$(generate_password)
    local api_key=$(generate_password)
    
    echo ""
    echo -e "${YELLOW}Generando configuración...${NC}"
    
    # Copiar y personalizar docker-compose
    cp "$template_dir/docker-compose.yml" "$app_dir/"
    
    # Crear archivo .env personalizado
    cat > "$app_dir/.env" << EOF
# Configuración generada automáticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')

DOMAIN=$domain
APP_NAME=${app_name}_${service_num}
SERVICE_NUMBER=$service_num

# Base de datos
DB_NAME=$db_name
DB_USER=${app_name}
DB_PASSWORD=$db_password

# Credenciales de administrador
ADMIN_EMAIL=$admin_email
ADMIN_PASSWORD=$admin_password

# API Key (si aplica)
API_KEY=$api_key

# Puertos (ajustar según necesidad)
APP_PORT=$((3000 + service_num))
DB_PORT=$((5432 + service_num))
EOF

    # Copiar README si existe
    if [ -f "$template_dir/README.md" ]; then
        cp "$template_dir/README.md" "$app_dir/"
    fi
    
    # Reemplazar variables en docker-compose.yml
    cd "$app_dir"
    
    # Usar sed para reemplazar placeholders
    sed -i "s/\${DOMAIN}/$domain/g" docker-compose.yml
    sed -i "s/\${APP_NAME}/${app_name}_${service_num}/g" docker-compose.yml
    sed -i "s/\${DB_NAME}/$db_name/g" docker-compose.yml
    sed -i "s/\${DB_PASSWORD}/$db_password/g" docker-compose.yml
    
    echo -e "${YELLOW}Iniciando contenedores...${NC}"
    docker-compose up -d
    
    cd "$PATH_INSTALL"
    
    # Guardar credenciales
    save_credentials "$domain" "$app_name" "$admin_email" "$admin_password" "$db_password"
    
    echo ""
    echo -e "${GREEN}✅ $app_name instalado correctamente${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  URL: https://$domain${NC}"
    echo -e "${CYAN}  Email: $admin_email${NC}"
    echo -e "${CYAN}  Password: $admin_password${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📝 Credenciales guardadas en: $CREDENTIALS_FILE${NC}"
    echo ""
}

# ============================================
# LISTAR APLICACIONES INSTALADAS
# ============================================

list_installed_apps() {
    banner
    echo -e "${GREEN}Aplicaciones Instaladas:${NC}\n"
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}  No hay aplicaciones instaladas${NC}\n"
        return
    fi
    
    local count=1
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            local app_name=$(basename "$app_dir")
            cd "$app_dir"
            
            local status="⏸️  Detenido"
            if docker-compose ps 2>/dev/null | grep -q "Up"; then
                status="✅ Ejecutándose"
            fi
            
            echo -e "  ${BLUE}[$count]${NC} $app_name - $status"
            cd "$PATH_INSTALL"
            ((count++))
        fi
    done
    echo ""
}

# ============================================
# VER CREDENCIALES
# ============================================

view_credentials() {
    banner
    echo -e "${GREEN}Credenciales Guardadas:${NC}\n"
    
    if [ -f "$CREDENTIALS_FILE" ]; then
        cat "$CREDENTIALS_FILE"
    else
        echo -e "${YELLOW}  No hay credenciales guardadas${NC}\n"
    fi
}

# ============================================
# MENÚ PRINCIPAL
# ============================================

show_menu() {
    banner
    echo -e "${GREEN}Aplicaciones Disponibles:${NC}\n"
    
    echo -e "  ${BLUE}[ 01 ]${NC} - N8N (Automatización de workflows)"
    echo -e "  ${BLUE}[ 02 ]${NC} - NocoDB (Base de datos sin código)"
    echo -e "  ${BLUE}[ 03 ]${NC} - Evolution API (WhatsApp API)"
    echo -e "  ${BLUE}[ 04 ]${NC} - Typebot (Constructor de chatbots)"
    echo -e "  ${BLUE}[ 05 ]${NC} - Chatwoot (Soporte al cliente)"
    echo -e "  ${BLUE}[ 06 ]${NC} - Flowise (Apps con LLMs)"
    echo -e "  ${BLUE}[ 07 ]${NC} - MinIO (Object Storage S3)"
    echo -e "  ${BLUE}[ 08 ]${NC} - MongoDB (Base de datos NoSQL)"
    echo -e "  ${BLUE}[ 09 ]${NC} - Redis (Cache en memoria)"
    echo -e "  ${BLUE}[ 10 ]${NC} - RabbitMQ (Message broker)"
    
    echo -e "\n${MAGENTA}Gestión:${NC}"
    echo -e "  ${YELLOW}[ 88 ]${NC} - Ver credenciales guardadas"
    echo -e "  ${YELLOW}[ 89 ]${NC} - Ver apps instaladas"
    echo -e "  ${YELLOW}[ 90 ]${NC} - Configurar proxy (Primera vez)"
    
    echo -e "\n  ${RED}[ 00 ]${NC} - Salir\n"
}

process_selection() {
    local choice=$1
    
    case $choice in
        1|01)  install_app "n8n" ;;
        2|02)  install_app "nocodb" ;;
        3|03)  install_app "evolution-api" ;;
        4|04)  install_app "typebot" ;;
        5|05)  install_app "chatwoot" ;;
        6|06)  install_app "flowise" ;;
        7|07)  install_app "minio" ;;
        8|08)  install_app "mongodb" ;;
        9|09)  install_app "redis" ;;
        10)    install_app "rabbitmq" ;;
        88)    view_credentials ;;
        89)    list_installed_apps ;;
        90)    setup_proxy ;;
        0|00)  
            echo -e "${GREEN}¡Hasta pronto!${NC}"
            exit 0
            ;;
        *)     
            echo -e "${RED}❌ Opción inválida${NC}"
            ;;
    esac
}

# ============================================
# INICIO DEL SCRIPT
# ============================================

main() {
    # Verificar si se ejecuta como root
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
        echo -e "${YELLOW}Usa: sudo $0${NC}"
        exit 1
    fi
    
    # Crear directorios necesarios
    mkdir -p "$APPS_DIR"
    mkdir -p "$CERTS_DIR"
    
    # Verificar dependencias
    check_dependencies
    
    # Menú principal
    while true; do
        show_menu
        read -p "Selecciona una opción: " choice
        echo ""
        process_selection "$choice"
        echo ""
        read -p "Presiona ENTER para continuar..."
    done
}

main