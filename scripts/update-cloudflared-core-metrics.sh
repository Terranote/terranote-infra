#!/bin/bash
# Script para actualizar cloudflared con el hostname de métricas de terranote-core
# Ejecutar con: bash update-cloudflared-core-metrics.sh
# Requisitos: El usuario debe tener permisos sudo sin contraseña (NOPASSWD)

set -e

CONFIG_FILE="/etc/cloudflared/config.yml"
HOSTNAME="terranote-core-metrics.osm.lat"
SERVICE_PORT="8002"

echo "=== Actualizando configuración de cloudflared ==="
echo ""

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
    echo "⚠️  Advertencia: Este script requiere permisos sudo sin contraseña"
    echo "Si el usuario no tiene permisos sudo configurados, el script fallará"
    echo ""
fi

# Verificar que el archivo existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: No se encontró $CONFIG_FILE"
    exit 1
fi

# Hacer backup
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "✓ Backup creado: $BACKUP_FILE"
echo ""

# Verificar si ya existe
if grep -q "$HOSTNAME" "$CONFIG_FILE"; then
    echo "✓ El hostname $HOSTNAME ya está configurado"
    echo ""
    echo "Configuración actual:"
    grep -A 2 "$HOSTNAME" "$CONFIG_FILE"
    echo ""
    read -p "¿Deseas actualizarlo? (s/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Operación cancelada"
        exit 0
    fi
    # Eliminar la entrada existente
    sed -i "/$HOSTNAME/,+1d" "$CONFIG_FILE"
fi

echo "Agregando hostname $HOSTNAME..."
# Agregar antes del catch-all (http_status:404)
sed -i "/http_status:404/i\ - hostname: $HOSTNAME\\"$'\n'"   service: http://localhost:$SERVICE_PORT" "$CONFIG_FILE"

echo "✓ Hostname agregado"
echo ""
echo "Configuración actualizada:"
grep -A 2 "$HOSTNAME" "$CONFIG_FILE"
echo ""

echo "Reiniciando cloudflared..."
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
echo "Verificar acceso:"
echo "  curl -u admin:TU_CONTRASEÑA https://$HOSTNAME/metrics"

