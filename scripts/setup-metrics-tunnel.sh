#!/usr/bin/env bash
# Script para configurar el túnel de métricas con Cloudflare
# Ejecutar con: bash setup-metrics-tunnel.sh

set -euo pipefail

echo "=== Configuración de Túnel de Métricas ==="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verificar que estamos en el servidor correcto
if [ ! -f "/etc/cloudflared/config.yml" ]; then
    echo -e "${RED}Error: No se encontró la configuración de cloudflared${NC}"
    echo "Este script debe ejecutarse en el servidor donde está cloudflared"
    exit 1
fi

ADAPTER_ENV="/home/terranote/terranote-adapter-telegram/.env"
CLOUDFLARED_CONFIG="/etc/cloudflared/config.yml"

echo -e "${YELLOW}1. Configurando autenticación para métricas...${NC}"

# Generar contraseña si no existe
if ! grep -q "^METRICS_PASSWORD=" "$ADAPTER_ENV" 2>/dev/null; then
    echo "Generando contraseña segura..."
    PASSWORD=$(openssl rand -base64 24)
    
    # Agregar al .env
    if [ -f "$ADAPTER_ENV" ]; then
        echo "" >> "$ADAPTER_ENV"
        echo "# Metrics endpoint authentication" >> "$ADAPTER_ENV"
        echo "METRICS_USERNAME=admin" >> "$ADAPTER_ENV"
        echo "METRICS_PASSWORD=$PASSWORD" >> "$ADAPTER_ENV"
        echo -e "${GREEN}✓ Credenciales agregadas al .env${NC}"
        echo ""
        echo -e "${YELLOW}Credenciales generadas:${NC}"
        echo "  Usuario: admin"
        echo "  Contraseña: $PASSWORD"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANTE: Guarda esta contraseña de forma segura${NC}"
        echo ""
    else
        echo -e "${RED}Error: No se encontró $ADAPTER_ENV${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ Autenticación ya configurada${NC}"
    PASSWORD=$(grep "^METRICS_PASSWORD=" "$ADAPTER_ENV" | cut -d'=' -f2)
    USERNAME=$(grep "^METRICS_USERNAME=" "$ADAPTER_ENV" | cut -d'=' -f2 || echo "admin")
    echo "  Usuario: $USERNAME"
    echo "  Contraseña: (ya configurada)"
fi

echo ""
echo -e "${YELLOW}2. Verificando configuración de cloudflared...${NC}"

# Verificar si el hostname ya existe
if grep -q "terranote-tg-metrics.osm.lat" "$CLOUDFLARED_CONFIG" 2>/dev/null; then
    echo -e "${GREEN}✓ Hostname terranote-tg-metrics.osm.lat ya configurado${NC}"
else
    echo -e "${YELLOW}Agregando hostname terranote-tg-metrics.osm.lat...${NC}"
    
    # Crear backup
    sudo cp "$CLOUDFLARED_CONFIG" "${CLOUDFLARED_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Agregar el nuevo hostname antes del catch-all
    sudo sed -i '/- service: http_status:404/i\
 - hostname: terranote-tg-metrics.osm.lat\
   service: http://localhost:3000' "$CLOUDFLARED_CONFIG"
    
    echo -e "${GREEN}✓ Hostname agregado a cloudflared${NC}"
fi

echo ""
echo -e "${YELLOW}3. Reiniciando servicios...${NC}"

# Reiniciar adaptador
echo "  Reiniciando terranote-adapter-telegram..."
sudo systemctl restart terranote-adapter-telegram
sleep 2

# Verificar que el adaptador esté corriendo
if sudo systemctl is-active --quiet terranote-adapter-telegram; then
    echo -e "${GREEN}✓ Adaptador reiniciado correctamente${NC}"
else
    echo -e "${RED}✗ Error al reiniciar el adaptador${NC}"
    sudo systemctl status terranote-adapter-telegram --no-pager -l | head -10
    exit 1
fi

# Reiniciar cloudflared
echo "  Reiniciando cloudflared..."
sudo systemctl restart cloudflared
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
echo "     * Nombre: terranote-tg-metrics"
echo "     * Target: 1b718247-fe2d-4391-84c0-819c1501e6c2.cfargotunnel.com"
echo "     * Proxy: Activado (naranja)"
echo ""
echo "2. Esperar propagación DNS (1-2 minutos)"
echo ""
echo "3. Verificar acceso:"
echo "   curl -u admin:$PASSWORD https://terranote-tg-metrics.osm.lat/metrics"
echo ""
echo -e "${YELLOW}Nota:${NC} Si no configuraste el DNS aún, puedes probar localmente:"
echo "   curl -u admin:$PASSWORD http://localhost:3000/metrics"

