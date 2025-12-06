#!/bin/bash

# ============================================
# APPFORGE - Multi-App VPS Installer v2.1
# Repositorio: https://github.com/zjceo/appforge
# MEJORADO: Procesamiento correcto de templates
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
    ║          Multi-App VPS Installer & Manager v2.1         ║
    ║                  🚀 MEJORADO - 2024                      ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

generate_password() {
    # Generar password de 24 caracteres alfanuméricos
    head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24
}

generate_secret() {
    # Generar secret de 32 caracteres (para JWT, encryption, etc)
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

generate_db_name() {
    local domain=$1
    local service_num=$2
    echo "${domain}_${service_num}" | sed 's/\./_/g' | sed 's/-/_/g' | cut -c1-63
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$ ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================
# PROCESAMIENTO DE TEMPLATES
# ============================================

process_template() {
    local template_file=$1
    local output_file=$2
    local env_file=$3
    
    echo -e "${YELLOW}  → Procesando template...${NC}"
    
    # Cargar variables del .env
    set -a
    source "$env_file"
    set +a
    
    # Verificar si envsubst está disponible
    if command -v envsubst &> /dev/null; then
        # Método 1: usar envsubst (más confiable)
        envsubst < "$template_file" > "$output_file"
        echo -e "${GREEN}    ✓ Template procesado con envsubst${NC}"
    else
        # Método 2: usar sed para variables específicas
        echo -e "${YELLOW}    ⚠ envsubst no disponible, usando sed${NC}"
        
        cp "$template_file" "$output_file"
        
        # Reemplazar variables conocidas
        sed -i.bak "s|\${DOMAIN}|$DOMAIN|g" "$output_file"
        sed -i.bak "s|\${BOT_DOMAIN}|$BOT_DOMAIN|g" "$output_file"
        sed -i.bak "s|\${CONSOLE_DOMAIN}|$CONSOLE_DOMAIN|g" "$output_file"
        sed -i.bak "s|\${APP_NAME}|$APP_NAME|g" "$output_file"
        sed -i.bak "s|\${SERVICE_NUMBER}|$SERVICE_NUMBER|g" "$output_file"
        sed -i.bak "s|\${DB_NAME}|$DB_NAME|g" "$output_file"
        sed -i.bak "s|\${DB_USER}|$DB_USER|g" "$output_file"
        sed -i.bak "s|\${DB_PASSWORD}|$DB_PASSWORD|g" "$output_file"
        sed -i.bak "s|\${DB_PORT}|$DB_PORT|g" "$output_file"
        sed -i.bak "s|\${ADMIN_EMAIL}|$ADMIN_EMAIL|g" "$output_file"
        sed -i.bak "s|\${ADMIN_PASSWORD}|$ADMIN_PASSWORD|g" "$output_file"
        sed -i.bak "s|\${API_KEY}|$API_KEY|g" "$output_file"
        sed -i.bak "s|\${ENCRYPTION_SECRET}|$ENCRYPTION_SECRET|g" "$output_file"
        
        # Eliminar archivos de backup
        rm -f "$output_file.bak"
        
        echo -e "${GREEN}    ✓ Template procesado con sed${NC}"
    fi
    
    # Validar sintaxis del archivo generado
    if [ "${output_file##*.}" = "yml" ]; then
        if docker-compose -f "$output_file" config &> /dev/null; then
            echo -e "${GREEN}    ✓ Sintaxis YAML válida${NC}"
        else
            echo -e "${RED}    ✗ Error en sintaxis YAML${NC}"
            return 1
        fi
    fi
    
    return 0
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
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        echo -e "${GREEN}✓ Docker detectado: $docker_version${NC}"
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose no está instalado${NC}"
        missing_deps=true
    else
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        echo -e "${GREEN}✓ Docker Compose detectado: $compose_version${NC}"
    fi
    
    # Verificar envsubst (opcional pero recomendado)
    if ! command -v envsubst &> /dev/null; then
        echo -e "${YELLOW}⚠ envsubst no detectado (se usará sed como alternativa)${NC}"
    else
        echo -e "${GREEN}✓ envsubst detectado${NC}"
    fi
    
    # Verificar openssl (para generar secrets)
    if ! command -v openssl &> /dev/null; then
        echo -e "${YELLOW}⚠ openssl no detectado (se usará método alternativo)${NC}"
    else
        echo -e "${GREEN}✓ openssl detectado${NC}"
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
    apt-get -y install git curl wget gnupg lsb-release ca-certificates gettext-base
    
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
        
        # Verificar si está corriendo
        if docker ps | grep -q "traefik"; then
            echo -e "${GREEN}✓ Traefik está corriendo${NC}"
        else
            echo -e "${YELLOW}⚠ Traefik configurado pero no está corriendo${NC}"
            read -p "¿Deseas iniciarlo? (s/n): " start_traefik
            if [ "$start_traefik" = "s" ]; then
                cd "$PROXY_DIR"
                docker-compose up -d
                cd "$PATH_INSTALL"
                echo -e "${GREEN}✓ Traefik iniciado${NC}"
            fi
        fi
        return
    fi
    
    echo -e "${YELLOW}Configurando Traefik como proxy inverso...${NC}"
    
    mkdir -p "$PROXY_DIR/traefik"
    
    # Solicitar email para Let's Encrypt
    while true; do
        read -p "Email para certificados SSL (Let's Encrypt): " ssl_email
        
        if [[ $ssl_email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo -e "${RED}❌ Email inválido, intenta nuevamente${NC}"
        fi
    done
    
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
    image: traefik:v3.2
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
      - "traefik.http.routers.portainer.rule=Host(`portainer.localhost`)"
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

    # Crear archivo acme.json con permisos correctos
    touch "$PROXY_DIR/traefik/acme.json"
    chmod 600 "$PROXY_DIR/traefik/acme.json"

    cd "$PROXY_DIR"
    docker-compose up -d
    cd "$PATH_INSTALL"
    
    echo -e "${GREEN}✓ Traefik instalado correctamente${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Dashboard: http://$(hostname -I | awk '{print $1}'):8080${NC}"
    echo -e "${CYAN}  Portainer: https://portainer.localhost (configurar DNS)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
# GENERACIÓN AUTOMÁTICA DE SECRETS
# ============================================

generate_env_secrets() {
    local template_env=$1
    local output_env=$2
    
    echo -e "${YELLOW}  → Generando secrets automáticos...${NC}"
    
    # Leer el template línea por línea
    while IFS= read -r line; do
        # Detectar si la línea tiene el marcador de generación automática
        if [[ "$line" =~ ^[[:space:]]*#.*openssl[[:space:]]+rand[[:space:]]+-base64[[:space:]]+([0-9]+) ]]; then
            local length="${BASH_REMATCH[1]}"
            
            # Leer la siguiente línea que debería ser la variable
            read -r next_line
            
            if [[ "$next_line" =~ ^([A-Z_]+)= ]]; then
                local var_name="${BASH_REMATCH[1]}"
                local secret_value=$(openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length")
                
                echo -e "${GREEN}    ✓ $var_name generado (${length} chars)${NC}"
                echo "$line" >> "$output_env"
                echo "${var_name}=${secret_value}" >> "$output_env"
            else
                echo "$line" >> "$output_env"
                echo "$next_line" >> "$output_env"
            fi
        else
            echo "$line" >> "$output_env"
        fi
    done < "$template_env"
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
    
    # Dominios adicionales según la app
    local bot_domain=""
    local console_domain=""
    
    if [ "$app_name" = "typebot" ]; then
        read -p "Dominio para bots (ej: bot.$domain): " bot_domain
        [ -z "$bot_domain" ] && bot_domain="bot.$domain"
    fi
    
    if [ "$app_name" = "minio" ]; then
        read -p "Dominio para consola (ej: console.$domain): " console_domain
        [ -z "$console_domain" ] && console_domain="console.$domain"
    fi
    
    # Solicitar número de servicio
    read -p "Número de servicio (1-99) [1]: " service_num
    [ -z "$service_num" ] && service_num=1
    
    # Crear directorio de instalación
    local app_dir="$APPS_DIR/${app_name}-${service_num}"
    
    if [ -d "$app_dir" ]; then
        echo -e "${YELLOW}⚠️  El directorio $app_dir ya existe${NC}"
        read -p "¿Deseas continuar y sobrescribir? (s/n): " confirm
        if [ "$confirm" != "s" ]; then
            return 1
        fi
        rm -rf "$app_dir"
    fi
    
    mkdir -p "$app_dir"
    
    # Generar credenciales
    local db_name=$(generate_db_name "$domain" "$service_num")
    local db_password=$(generate_password)
    local admin_email="${app_name}@${domain}"
    local admin_password=$(generate_password)
    local api_key=$(generate_secret)
    local encryption_secret=$(generate_secret)
    
    echo ""
    echo -e "${YELLOW}Generando configuración...${NC}"
    
    # Crear archivo .env PRIMERO
    cat > "$app_dir/.env" << EOF
# ============================================
# Configuración generada automáticamente
# Fecha: $(date '+%Y-%m-%d %H:%M:%S')
# App: $app_name
# ============================================

# DOMINIOS
DOMAIN=$domain
BOT_DOMAIN=$bot_domain
CONSOLE_DOMAIN=$console_domain
APP_NAME=${app_name}_${service_num}
SERVICE_NUMBER=$service_num

# BASE DE DATOS
DB_NAME=$db_name
DB_USER=${app_name}
DB_PASSWORD=$db_password
DB_PORT=$((5432 + service_num))

# CREDENCIALES DE ADMINISTRADOR
ADMIN_EMAIL=$admin_email
ADMIN_PASSWORD=$admin_password

# SEGURIDAD
API_KEY=$api_key
ENCRYPTION_SECRET=$encryption_secret

# SMTP (Configurar según tu proveedor)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=$admin_email
SMTP_SECURE=false

# STORAGE S3/MinIO (Opcional)
S3_ENDPOINT=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_BUCKET=${app_name}
S3_REGION=us-east-1

# TIMEZONE
TIMEZONE=America/Lima
TZ=America/Lima
EOF

    echo -e "${GREEN}  ✓ Archivo .env creado${NC}"
    
    # AHORA procesar el docker-compose.yml con las variables
    if ! process_template "$template_dir/docker-compose.yml" "$app_dir/docker-compose.yml" "$app_dir/.env"; then
        echo -e "${RED}❌ Error al procesar template${NC}"
        return 1
    fi
    
    # Copiar archivos adicionales
    if [ -f "$template_dir/.env.example" ]; then
        cp "$template_dir/.env.example" "$app_dir/.env.example"
        echo -e "${GREEN}  ✓ .env.example copiado${NC}"
    fi
    
    if [ -f "$template_dir/README.md" ]; then
        cp "$template_dir/README.md" "$app_dir/README.md"
        echo -e "${GREEN}  ✓ README.md copiado${NC}"
    fi
    
    # Iniciar contenedores
    echo ""
    echo -e "${YELLOW}Iniciando contenedores...${NC}"
    cd "$app_dir"
    
    # Pull de imágenes primero
    echo -e "${YELLOW}  → Descargando imágenes...${NC}"
    docker-compose pull
    
    # Iniciar servicios
    echo -e "${YELLOW}  → Iniciando servicios...${NC}"
    docker-compose up -d
    
    # Esperar a que los servicios inicien
    echo -e "${YELLOW}  → Esperando inicialización...${NC}"
    sleep 10
    
    # Verificar estado
    local running=$(docker-compose ps | grep -c "Up" || echo "0")
    local total=$(docker-compose ps --services | wc -l)
    
    if [ "$running" -eq "$total" ]; then
        echo -e "${GREEN}  ✓ Todos los servicios iniciados ($running/$total)${NC}"
    else
        echo -e "${YELLOW}  ⚠ Algunos servicios no iniciaron ($running/$total)${NC}"
        echo -e "${YELLOW}    Revisa los logs: cd $app_dir && docker-compose logs -f${NC}"
    fi
    
    cd "$PATH_INSTALL"
    
    # Información adicional según la app
    local extra_info=""
    case $app_name in
        typebot)
            extra_info="Builder: https://$domain\nViewer: https://$bot_domain\nEncryption Secret: $encryption_secret"
            ;;
        minio)
            extra_info="API: https://$domain\nConsole: https://$console_domain\nAccess Key: $admin_email\nSecret Key: $admin_password"
            ;;
        chatwoot)
            extra_info="Super Admin habilitado\nConfigura SMTP para notificaciones"
            ;;
        evolution-api)
            extra_info="API Key: $api_key\nDocumentación: https://doc.evolution-api.com/"
            ;;
    esac
    
    # Guardar credenciales
    save_credentials "$domain" "$app_name" "$admin_email" "$admin_password" "$db_password" "$extra_info"
    
    echo ""
    echo -e "${GREEN}✅ $app_name instalado correctamente${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  URL: https://$domain${NC}"
    if [ -n "$bot_domain" ]; then
        echo -e "${CYAN}  Bot URL: https://$bot_domain${NC}"
    fi
    if [ -n "$console_domain" ]; then
        echo -e "${CYAN}  Console: https://$console_domain${NC}"
    fi
    echo -e "${CYAN}  Email: $admin_email${NC}"
    echo -e "${CYAN}  Password: $admin_password${NC}"
    echo -e "${CYAN}  DB Password: $db_password${NC}"
    if [ "$app_name" = "evolution-api" ] || [ "$app_name" = "minio" ]; then
        echo -e "${CYAN}  API Key: $api_key${NC}"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}📝 Credenciales guardadas en: $CREDENTIALS_FILE${NC}"
    echo -e "${YELLOW}📁 Archivos en: $app_dir${NC}"
    echo ""
    
    # Consejos post-instalación
    echo -e "${BLUE}💡 Próximos pasos:${NC}"
    case $app_name in
        chatwoot)
            echo -e "  1. Accede a https://$domain"
            echo -e "  2. Crea tu cuenta de admin"
            echo -e "  3. Configura SMTP en $app_dir/.env"
            echo -e "  4. Reinicia: cd $app_dir && docker-compose restart"
            ;;
        typebot)
            echo -e "  1. Configura S3/MinIO en $app_dir/.env"
            echo -e "  2. Reinicia: cd $app_dir && docker-compose restart"
            echo -e "  3. Accede al builder: https://$domain"
            ;;
        evolution-api)
            echo -e "  1. Crea una instancia vía API"
            echo -e "  2. Usa el API Key en tus peticiones"
            echo -e "  3. Documentación: https://doc.evolution-api.com/"
            ;;
        *)
            echo -e "  1. Accede a https://$domain"
            echo -e "  2. Configura según tus necesidades"
            echo -e "  3. Revisa el README: $app_dir/README.md"
            ;;
    esac
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
            local status_color=$YELLOW
            
            if docker-compose ps 2>/dev/null | grep -q "Up"; then
                status="✅ Ejecutándose"
                status_color=$GREEN
            fi
            
            # Obtener dominio
            local domain=$(grep "^DOMAIN=" .env 2>/dev/null | cut -d'=' -f2)
            
            echo -e "  ${BLUE}[$count]${NC} ${status_color}$app_name${NC} - $status"
            if [ -n "$domain" ]; then
                echo -e "      🌐 https://$domain"
            fi
            
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
    echo -e "  ${YELLOW}[ 91 ]${NC} - Validar configuración"
    
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
        91)    run_validator ;;
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
# VALIDADOR DE CONFIGURACIÓN
# ============================================

run_validator() {
    if [ -f "./utils/validate-setup.sh" ]; then
        chmod +x ./utils/validate-setup.sh
        ./utils/validate-setup.sh
    else
        echo -e "${RED}❌ Script de validación no encontrado${NC}"
        echo -e "${YELLOW}   Descarga desde: https://github.com/zjceo/appforge${NC}"
    fi
}

# ============================================
# ACTUALIZACIÓN DEL INSTALADOR
# ============================================

self_update() {
    echo -e "${YELLOW}🔄 Verificando actualizaciones...${NC}"
    
    if [ -d ".git" ]; then
        git fetch origin
        
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})
        
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "${CYAN}📦 Nueva versión disponible${NC}"
            read -p "¿Deseas actualizar? (s/n): " update_choice
            
            if [ "$update_choice" = "s" ]; then
                git pull origin main
                echo -e "${GREEN}✓ AppForge actualizado${NC}"
                echo -e "${YELLOW}⚠ Reinicia el instalador para usar la nueva versión${NC}"
                exit 0
            fi
        else
            echo -e "${GREEN}✓ Ya tienes la última versión${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ No es un repositorio git${NC}"
        echo -e "${CYAN}  Para habilitar actualizaciones automáticas:${NC}"
        echo -e "${CYAN}  git clone https://github.com/zjceo/appforge${NC}"
    fi
    
    echo ""
}

# ============================================
# MENÚ DE CONFIGURACIÓN AVANZADA
# ============================================

advanced_menu() {
    banner
    echo -e "${MAGENTA}Configuración Avanzada:${NC}\n"
    
    echo -e "  ${BLUE}[ 1 ]${NC} - Configurar red Docker"
    echo -e "  ${BLUE}[ 2 ]${NC} - Verificar puertos en uso"
    echo -e "  ${BLUE}[ 3 ]${NC} - Limpiar contenedores huérfanos"
    echo -e "  ${BLUE}[ 4 ]${NC} - Verificar salud de servicios"
    echo -e "  ${BLUE}[ 5 ]${NC} - Exportar configuración"
    echo -e "  ${BLUE}[ 6 ]${NC} - Importar configuración"
    echo -e "\n  ${RED}[ 0 ]${NC} - Volver\n"
    
    read -p "Selecciona una opción: " adv_choice
    
    case $adv_choice in
        1) configure_network ;;
        2) check_ports ;;
        3) cleanup_orphans ;;
        4) health_check ;;
        5) export_config ;;
        6) import_config ;;
        0) return ;;
        *) echo -e "${RED}❌ Opción inválida${NC}" ;;
    esac
    
    read -p "Presiona ENTER para continuar..."
}

configure_network() {
    echo -e "${YELLOW}🌐 Configurando red Docker...${NC}"
    
    if docker network ls | grep -q "appforge-network"; then
        echo -e "${GREEN}✓ Red appforge-network ya existe${NC}"
        
        # Mostrar información
        echo -e "\n${CYAN}Información de la red:${NC}"
        docker network inspect appforge-network --format='Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
        
        echo -e "\n${YELLOW}Contenedores conectados:${NC}"
        docker network inspect appforge-network --format='{{range .Containers}}{{.Name}}
{{end}}'
    else
        echo -e "${YELLOW}Creando red appforge-network...${NC}"
        docker network create appforge-network
        echo -e "${GREEN}✓ Red creada correctamente${NC}"
    fi
    
    echo ""
}

check_ports() {
    echo -e "${YELLOW}🔍 Verificando puertos en uso...${NC}\n"
    
    IMPORTANT_PORTS=(80 443 3000 5432 6379 8080 9000 27017)
    
    for port in "${IMPORTANT_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            local process=$(lsof -i :$port 2>/dev/null | tail -1 | awk '{print $1}' || echo "Unknown")
            echo -e "${YELLOW}⚠${NC} Puerto $port en uso por: $process"
        else
            echo -e "${GREEN}✓${NC} Puerto $port disponible"
        fi
    done
    
    echo ""
}

cleanup_orphans() {
    echo -e "${YELLOW}🧹 Limpiando contenedores huérfanos...${NC}"
    
    docker container prune -f
    docker network prune -f
    docker image prune -f
    
    echo -e "${GREEN}✓ Limpieza completada${NC}"
    echo ""
}

health_check() {
    echo -e "${YELLOW}🏥 Verificando salud de servicios...${NC}\n"
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        echo -e "${YELLOW}No hay aplicaciones instaladas${NC}"
        return
    fi
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
            local app_name=$(basename "$app_dir")
            
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}$app_name${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            
            cd "$app_dir"
            
            # Verificar cada servicio
            local services=$(docker-compose ps --services 2>/dev/null)
            
            for service in $services; do
                local container=$(docker-compose ps -q "$service" 2>/dev/null | head -n1)
                
                if [ -n "$container" ]; then
                    local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
                    local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
                    
                    if [ "$status" = "running" ]; then
                        if [ "$health" = "healthy" ]; then
                            echo -e "  ${GREEN}✓${NC} $service: running (healthy)"
                        elif [ "$health" = "unhealthy" ]; then
                            echo -e "  ${RED}✗${NC} $service: running (unhealthy)"
                        else
                            echo -e "  ${GREEN}✓${NC} $service: running"
                        fi
                    else
                        echo -e "  ${RED}✗${NC} $service: $status"
                    fi
                else
                    echo -e "  ${RED}✗${NC} $service: not running"
                fi
            done
            
            cd "$PATH_INSTALL"
            echo ""
        fi
    done
}

export_config() {
    echo -e "${YELLOW}📤 Exportando configuración...${NC}"
    
    local export_file="appforge-config-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    tar czf "$export_file" \
        --exclude="$APPS_DIR/*/node_modules" \
        --exclude="$APPS_DIR/*/.git" \
        "$CREDENTIALS_FILE" \
        "$PROXY_DIR" \
        2>/dev/null || true
    
    if [ -f "$export_file" ]; then
        local size=$(du -h "$export_file" | cut -f1)
        echo -e "${GREEN}✓ Configuración exportada: $export_file ($size)${NC}"
    else
        echo -e "${RED}❌ Error al exportar configuración${NC}"
    fi
    
    echo ""
}

import_config() {
    echo -e "${YELLOW}📥 Importar configuración${NC}"
    echo ""
    
    echo "Archivos disponibles:"
    ls -1 appforge-config-*.tar.gz 2>/dev/null || echo "  (ninguno)"
    echo ""
    
    read -p "Nombre del archivo: " import_file
    
    if [ -f "$import_file" ]; then
        echo -e "${YELLOW}Extrayendo...${NC}"
        tar xzf "$import_file"
        echo -e "${GREEN}✓ Configuración importada${NC}"
    else
        echo -e "${RED}❌ Archivo no encontrado${NC}"
    fi
    
    echo ""
}

# ============================================
# INFORMACIÓN DEL SISTEMA
# ============================================

show_system_info() {
    banner
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🖥️  Información del Sistema${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # SO
    echo -e "${CYAN}Sistema Operativo:${NC}"
    cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2
    echo ""
    
    # Kernel
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo ""
    
    # CPU
    echo -e "${CYAN}CPU:${NC}"
    lscpu | grep "Model name" | cut -d':' -f2 | xargs
    echo ""
    
    # RAM
    echo -e "${CYAN}Memoria RAM:${NC}"
    free -h | grep Mem | awk '{print "  Total: "$2" | Usado: "$3" | Disponible: "$7}'
    echo ""
    
    # Disco
    echo -e "${CYAN}Disco:${NC}"
    df -h / | tail -1 | awk '{print "  Total: "$2" | Usado: "$3" | Disponible: "$4" | Uso: "$5}'
    echo ""
    
    # Docker
    if command -v docker &> /dev/null; then
        echo -e "${CYAN}Docker:${NC}"
        docker --version
        echo -e "  Contenedores: $(docker ps -q | wc -l) corriendo / $(docker ps -a -q | wc -l) total"
        echo -e "  Imágenes: $(docker images -q | wc -l)"
        echo -e "  Volúmenes: $(docker volume ls -q | wc -l)"
    fi
    
    echo ""
    
    # IP
    echo -e "${CYAN}Dirección IP:${NC}"
    hostname -I | awk '{print "  Local: "$1}'
    
    # IP pública
    local public_ip=$(curl -s ifconfig.me 2>/dev/null || echo "No disponible")
    echo -e "  Pública: $public_ip"
    
    echo ""
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
    mkdir -p "$TEMPLATES_DIR"
    mkdir -p "$PROXY_DIR"
    mkdir -p "./scripts"
    mkdir -p "./utils"
    
    # Verificar dependencias
    check_dependencies
    
    # Verificar actualizaciones (opcional)
    # self_update
    
    # Menú principal
    while true; do
        show_menu
        read -p "Selecciona una opción: " choice
        echo ""
        
        case $choice in
            99)
                advanced_menu
                ;;
            98)
                show_system_info
                read -p "Presiona ENTER para continuar..."
                ;;
            *)
                process_selection "$choice"
                ;;
        esac
        
        if [ "$choice" != "00" ] && [ "$choice" != "0" ]; then
            echo ""
            read -p "Presiona ENTER para continuar..."
        fi
    done
}

# Capturar Ctrl+C
trap 'echo -e "\n${YELLOW}Instalación interrumpida${NC}"; exit 130' INT

# Ejecutar
main
