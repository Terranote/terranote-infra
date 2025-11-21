#!/bin/bash
# Script para configurar el túnel de métricas de terranote-core con Cloudflare
# Ejecutar con: bash setup-core-metrics-tunnel.sh
# Requisitos: El usuario debe tener permisos sudo sin contraseña (NOPASSWD)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
CORE_DIR="/home/terranote/terranote-core"
CORE_ENV="$CORE_DIR/.env"
CLOUDFLARED_CONFIG="/etc/cloudflared/config.yml"
HOSTNAME="terranote-core-metrics.osm.lat"
SERVICE_PORT="8002"

echo -e "${YELLOW}=== Configuración de Métricas de Terranote Core ===${NC}"
echo ""

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Advertencia: Este script requiere permisos sudo sin contraseña${NC}"
    echo "Si el usuario no tiene permisos sudo configurados, algunos comandos fallarán"
    echo ""
    read -p "¿Continuar de todas formas? (s/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Verificar que estamos en el servidor correcto
if [ ! -f "$CLOUDFLARED_CONFIG" ]; then
    echo -e "${RED}Error: No se encontró la configuración de cloudflared${NC}"
    echo "Este script debe ejecutarse en el servidor donde está cloudflared"
    exit 1
fi

# Verificar que existe el directorio de terranote-core
if [ ! -d "$CORE_DIR" ]; then
    echo -e "${RED}Error: No se encontró el directorio $CORE_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}1. Configurando autenticación para métricas...${NC}"

# Generar contraseña si no existe
if ! grep -q "^METRICS_PASSWORD=" "$CORE_ENV" 2>/dev/null; then
    echo "Generando contraseña segura..."
    PASSWORD=$(openssl rand -base64 24)
    
    # Agregar al .env
    if [ -f "$CORE_ENV" ]; then
        echo "" >> "$CORE_ENV"
        echo "# Metrics endpoint authentication" >> "$CORE_ENV"
        echo "METRICS_USERNAME=admin" >> "$CORE_ENV"
        echo "METRICS_PASSWORD=$PASSWORD" >> "$CORE_ENV"
        echo -e "${GREEN}✓ Credenciales agregadas al .env${NC}"
        echo ""
        echo -e "${YELLOW}Credenciales generadas:${NC}"
        echo "  Usuario: admin"
        echo "  Contraseña: $PASSWORD"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANTE: Guarda esta contraseña de forma segura${NC}"
        echo ""
    else
        echo -e "${RED}Error: No se encontró $CORE_ENV${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Autenticación ya configurada${NC}"
    PASSWORD=$(grep "^METRICS_PASSWORD=" "$CORE_ENV" | cut -d'=' -f2)
    USERNAME=$(grep "^METRICS_USERNAME=" "$CORE_ENV" | cut -d'=' -f2 || echo "admin")
    echo "  Usuario: $USERNAME"
    echo "  Contraseña: (ya configurada)"
fi

echo ""
echo -e "${YELLOW}2. Verificando configuración de cloudflared...${NC}"

# Verificar si el hostname ya existe
if grep -q "$HOSTNAME" "$CLOUDFLARED_CONFIG" 2>/dev/null; then
    echo -e "${GREEN}✓ Hostname $HOSTNAME ya configurado${NC}"
    grep -A 2 "$HOSTNAME" "$CLOUDFLARED_CONFIG"
else
    echo -e "${YELLOW}Agregando hostname $HOSTNAME...${NC}"
    
    # Hacer backup
    sudo cp "$CLOUDFLARED_CONFIG" "${CLOUDFLARED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Agregar el hostname antes del catch-all (http_status:404)
    sudo sed -i "/http_status:404/i\ - hostname: $HOSTNAME\\"$'\n'"   service: http://localhost:$SERVICE_PORT" "$CLOUDFLARED_CONFIG"
    
    echo -e "${GREEN}✓ Hostname agregado a cloudflared${NC}"
fi

echo ""
echo -e "${YELLOW}3. Reiniciando servicios...${NC}"

# Reiniciar terranote-core
echo "  Reiniciando terranote-core..."
sudo systemctl restart terranote-core

# Esperar un momento
sleep 2

# Verificar que terranote-core esté corriendo
if sudo systemctl is-active --quiet terranote-core; then
    echo -e "${GREEN}✓ terranote-core reiniciado correctamente${NC}"
else
    echo -e "${RED}✗ Error al reiniciar terranote-core${NC}"
    sudo systemctl status terranote-core --no-pager -l | head -10
    exit 1
fi

# Reiniciar cloudflared
echo "  Reiniciando cloudflared..."
sudo systemctl restart cloudflared

# Esperar un momento
sleep 2

# Verificar que cloudflared esté corriendo
if sudo systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}✓ Cloudflared reiniciado correctamente${NC}"
else
    echo -e "${RED}✗ Error al reiniciar cloudflared${NC}"
    sudo systemctl status cloudflared --no-pager -l | head -10
    exit 1
fi

echo ""
echo -e "${GREEN}=== Configuración completada ===${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo ""
echo "1. Configurar DNS en Cloudflare:"
echo "   - Ir a Cloudflare Dashboard → DNS"
echo "   - Agregar registro CNAME:"
echo "     * Nombre: terranote-core-metrics"
echo "     * Target: 1b718247-fe2d-4391-84c0-819c1501e6c2.cfargotunnel.com"
echo "     * Proxy: Activado (naranja)"
echo ""
echo "2. Verificar acceso local:"
echo "   curl -u admin:$PASSWORD http://localhost:$SERVICE_PORT/metrics | head -20"
echo ""
echo "3. Verificar acceso público (después de configurar DNS):"
echo "   curl -u admin:$PASSWORD https://$HOSTNAME/metrics | head -20"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE: Guarda estas credenciales de forma segura${NC}"
echo "   Usuario: admin"
echo "   Contraseña: $PASSWORD"
echo ""

