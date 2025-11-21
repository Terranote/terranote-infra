#!/usr/bin/env bash
# Script para actualizar cloudflared con el hostname de métricas
# Ejecutar con: sudo bash update-cloudflared-metrics.sh

set -euo pipefail

CONFIG_FILE="/etc/cloudflared/config.yml"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== Actualizando configuración de cloudflared ==="
echo ""

# Verificar que el archivo existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No se encontró $CONFIG_FILE"
    exit 1
fi

# Crear backup
echo "1. Creando backup..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "   Backup guardado en: $BACKUP_FILE"
echo ""

# Verificar si ya existe
if grep -q "terranote-tg-metrics.osm.lat" "$CONFIG_FILE"; then
    echo "✓ El hostname terranote-tg-metrics.osm.lat ya está configurado"
    echo ""
    echo "Configuración actual:"
    grep -A 2 "terranote-tg-metrics.osm.lat" "$CONFIG_FILE"
    exit 0
fi

# Agregar el nuevo hostname antes del catch-all
echo "2. Agregando hostname terranote-tg-metrics.osm.lat..."
sed -i '/- service: http_status:404/i\
 - hostname: terranote-tg-metrics.osm.lat\
   service: http://localhost:3000' "$CONFIG_FILE"

echo "✓ Hostname agregado"
echo ""

# Mostrar la configuración actualizada
echo "3. Configuración actualizada:"
echo ""
grep -A 2 "terranote-tg-metrics.osm.lat" "$CONFIG_FILE"
echo ""

echo "4. Reiniciando cloudflared..."
systemctl restart cloudflared
sleep 2

if systemctl is-active --quiet cloudflared; then
    echo "✓ Cloudflared reiniciado correctamente"
else
    echo "✗ Error al reiniciar cloudflared"
    systemctl status cloudflared --no-pager -l | head -10
    exit 1
fi

echo ""
echo "=== Configuración completada ==="
echo ""
echo "Ahora puedes acceder a las métricas en:"
echo "  https://terranote-tg-metrics.osm.lat/metrics"
echo ""
echo "Credenciales (desde .env del adaptador):"
echo "  Usuario: admin"
echo "  Contraseña: (ver /home/terranote/terranote-adapter-telegram/.env)"

