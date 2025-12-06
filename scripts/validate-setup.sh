#!/bin/bash

# ============================================
# APPFORGE - Script de Validación Completo
# ============================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║          AppForge - Validador de Configuración          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# ============================================
# VALIDAR SISTEMA
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🖥️  Validando Sistema${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}✓${NC} Docker instalado: $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker no instalado"
    ((ERRORS++))
fi

# Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    echo -e "${GREEN}✓${NC} Docker Compose instalado: $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose no instalado"
    ((ERRORS++))
fi

# envsubst
if command -v envsubst &> /dev/null; then
    echo -e "${GREEN}✓${NC} envsubst instalado (procesamiento óptimo de templates)"
else
    echo -e "${YELLOW}⚠${NC} envsubst no instalado (se usará sed como alternativa)"
    ((WARNINGS++))
fi

# Red Docker
if docker network ls | grep -q "appforge-network"; then
    echo -e "${GREEN}✓${NC} Red appforge-network existe"
else
    echo -e "${YELLOW}⚠${NC} Red appforge-network no existe"
    echo -e "  Crear con: ${CYAN}docker network create appforge-network${NC}"
    ((WARNINGS++))
fi

# Espacio en disco
DISK_FREE=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')
if (( $(echo "$DISK_FREE < 5" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "${RED}✗${NC} Poco espacio en disco: ${DISK_FREE}GB disponible"
    ((ERRORS++))
else
    echo -e "${GREEN}✓${NC} Espacio en disco OK: ${DISK_FREE}GB disponible"
fi

# Memoria RAM
MEM_TOTAL=$(free -g | grep Mem | awk '{print $2}')
if [ "$MEM_TOTAL" -lt 2 ]; then
    echo -e "${YELLOW}⚠${NC} Memoria RAM baja: ${MEM_TOTAL}GB"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓${NC} Memoria RAM OK: ${MEM_TOTAL}GB"
fi

echo ""

# ============================================
# VALIDAR ESTRUCTURA
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📁 Validando Estructura${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

REQUIRED_DIRS=("templates" "scripts" "utils" "apps" "proxy")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "./$dir" ]; then
        echo -e "${GREEN}✓${NC} Directorio $dir existe"
    else
        echo -e "${RED}✗${NC} Directorio $dir no existe"
        ((ERRORS++))
    fi
done

REQUIRED_SCRIPTS=("install.sh" "scripts/backup.sh" "scripts/update-all.sh" "scripts/remove-app.sh" "scripts/restore.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "./$script" ]; then
        if [ -x "./$script" ]; then
            echo -e "${GREEN}✓${NC} Script $script existe y es ejecutable"
        else
            echo -e "${YELLOW}⚠${NC} Script $script existe pero no es ejecutable"
            echo -e "  Solución: ${CYAN}chmod +x $script${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} Script $script no existe"
        ((ERRORS++))
    fi
done

echo ""

# ============================================
# VALIDAR TEMPLATES
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📦 Validando Templates${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

APPS=("n8n" "nocodb" "evolution-api" "typebot" "chatwoot" "flowise" "minio" "mongodb" "redis" "rabbitmq")

for app in "${APPS[@]}"; do
    TEMPLATE_DIR="./templates/$app"
    
    if [ -d "$TEMPLATE_DIR" ]; then
        # docker-compose.yml
        if [ -f "$TEMPLATE_DIR/docker-compose.yml" ]; then
            echo -e "${GREEN}✓${NC} $app: docker-compose.yml existe"
            
            if command -v docker-compose &> /dev/null; then
                if docker-compose -f "$TEMPLATE_DIR/docker-compose.yml" config &> /dev/null; then
                    echo -e "  ${GREEN}→${NC} Sintaxis YAML válida"
                else
                    echo -e "  ${RED}→${NC} Sintaxis YAML inválida"
                    ((ERRORS++))
                fi
            fi
        else
            echo -e "${RED}✗${NC} $app: docker-compose.yml no existe"
            ((ERRORS++))
        fi
        
        # .env.example
        if [ -f "$TEMPLATE_DIR/.env.example" ]; then
            echo -e "${GREEN}✓${NC} $app: .env.example existe"
        else
            echo -e "${YELLOW}⚠${NC} $app: .env.example no existe"
            ((WARNINGS++))
        fi
        
        echo ""
    else
        echo -e "${RED}✗${NC} Template $app no existe"
        ((ERRORS++))
    fi
done

# ============================================
# VALIDAR PROXY
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔒 Validando Proxy${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ -f "./proxy/docker-compose.yml" ]; then
    echo -e "${GREEN}✓${NC} Proxy configurado"
    
    if docker ps | grep -q "traefik"; then
        echo -e "${GREEN}✓${NC} Traefik está corriendo"
    else
        echo -e "${YELLOW}⚠${NC} Traefik no está corriendo"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Proxy no configurado"
    ((ERRORS++))
fi

echo ""

# ============================================
# VALIDAR APPS INSTALADAS
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Validando Apps Instaladas${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ -d "./apps" ] && [ "$(ls -A ./apps 2>/dev/null)" ]; then
    for app_dir in ./apps/*; do
        if [ -d "$app_dir" ]; then
            APP_NAME=$(basename "$app_dir")
            
            cd "$app_dir"
            
            if [ -f ".env" ]; then
                echo -e "${GREEN}✓${NC} $APP_NAME: .env existe"
                
                if grep -q "CHANGE_ME" .env; then
                    echo -e "  ${RED}→${NC} Contraseñas por defecto detectadas"
                    ((ERRORS++))
                fi
            else
                echo -e "${RED}✗${NC} $APP_NAME: .env no existe"
                ((ERRORS++))
            fi
            
            RUNNING=$(docker-compose ps -q 2>/dev/null | wc -l)
            TOTAL=$(docker-compose ps --services 2>/dev/null | wc -l)
            
            if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
                echo -e "${GREEN}✓${NC} $APP_NAME: todos los servicios corriendo ($RUNNING/$TOTAL)"
            elif [ "$RUNNING" -gt 0 ]; then
                echo -e "${YELLOW}⚠${NC} $APP_NAME: algunos servicios corriendo ($RUNNING/$TOTAL)"
                ((WARNINGS++))
            else
                echo -e "${YELLOW}⚠${NC} $APP_NAME: servicios detenidos"
            fi
            
            cd - > /dev/null
            echo ""
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} No hay aplicaciones instaladas"
    echo ""
fi

# ============================================
# RESUMEN
# ============================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Resumen${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✨ Todo perfecto!${NC}\n"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS advertencia(s)${NC}\n"
    exit 0
else
    echo -e "${RED}❌ $ERRORS error(es) crítico(s)${NC}\n"
    exit 1
fi