#!/usr/bin/env bash
# Script para corregir la configuración de cloudflared
# Corrige el puerto del Core de 3002 a 8002

set -euo pipefail

CONFIG_FILE="/etc/cloudflared/config.yml"
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== Corrigiendo configuración de cloudflared ==="
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

# Verificar configuración actual
echo "2. Configuración actual:"
grep -A 1 "terranote-core-metrics.osm.lat" "$CONFIG_FILE" || echo "   No encontrado"
echo ""

# Corregir puerto de 3002 a 8002
if grep -q "terranote-core-metrics.osm.lat" "$CONFIG_FILE"; then
    echo "3. Corrigiendo puerto de terranote-core-metrics..."
    # Buscar la línea del hostname y la siguiente línea de service
    sed -i '/terranote-core-metrics.osm.lat/,+1 {
        /service:/ s|localhost:3002|localhost:8002|
    }' "$CONFIG_FILE"
    
    echo "   ✓ Puerto corregido a 8002"
else
    echo "   ⚠️  Hostname terranote-core-metrics.osm.lat no encontrado"
    echo "   Agregando configuración..."
    # Agregar antes del catch-all
    sed -i '/- service: http_status:404/i\
 - hostname: terranote-core-metrics.osm.lat\
   service: http://localhost:8002' "$CONFIG_FILE"
    echo "   ✓ Configuración agregada"
fi

echo ""

# Verificar que terranote-tg-metrics apunta correctamente
if grep -q "terranote-tg-metrics.osm.lat" "$CONFIG_FILE"; then
    TG_METRICS_PORT=$(grep -A 1 "terranote-tg-metrics.osm.lat" "$CONFIG_FILE" | grep "service:" | grep -o "localhost:[0-9]*" | cut -d: -f2)
    if [ "$TG_METRICS_PORT" != "3000" ]; then
        echo "4. Corrigiendo puerto de terranote-tg-metrics..."
        sed -i '/terranote-tg-metrics.osm.lat/,/service:/ {
            s|service: http://localhost:[0-9]*|service: http://localhost:3000|
        }' "$CONFIG_FILE"
        echo "   ✓ Puerto corregido a 3000"
    else
        echo "4. ✓ terranote-tg-metrics ya está configurado correctamente (puerto 3000)"
    fi
else
    echo "4. ⚠️  Hostname terranote-tg-metrics.osm.lat no encontrado"
fi

echo ""

# Mostrar configuración actualizada
echo "5. Configuración actualizada de métricas:"
echo ""
grep -B 1 -A 1 "metrics.osm.lat" "$CONFIG_FILE" || echo "   No se encontraron hostnames de métricas"
echo ""

# Validar formato YAML básico
echo "6. Validando formato YAML..."
if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
    echo "   ✓ Formato YAML válido"
else
    echo "   ⚠️  Advertencia: No se pudo validar YAML (puede requerir python3-yaml)"
fi

echo ""

# Reiniciar cloudflared
echo "7. Reiniciando cloudflared..."
if systemctl restart cloudflared; then
    sleep 2
    if systemctl is-active --quiet cloudflared; then
        echo "   ✓ Cloudflared reiniciado correctamente"
    else
        echo "   ✗ Error: Cloudflared no está activo después del reinicio"
        systemctl status cloudflared --no-pager -l | head -15
        echo ""
        echo "   Si hay errores, puedes restaurar el backup:"
        echo "   sudo cp $BACKUP_FILE $CONFIG_FILE"
        echo "   sudo systemctl restart cloudflared"
        exit 1
    fi
else
    echo "   ✗ Error al reiniciar cloudflared"
    exit 1
fi

echo ""
echo "=== Configuración completada ==="
echo ""
echo "Resumen de hostnames de métricas:"
echo "  - terranote-tg-metrics.osm.lat -> http://localhost:3000/metrics"
echo "  - terranote-core-metrics.osm.lat -> http://localhost:8002/metrics"
echo ""
echo "Para verificar:"
echo "  curl -u admin:CONTRASEÑA https://terranote-tg-metrics.osm.lat/metrics"
echo "  curl https://terranote-core-metrics.osm.lat/metrics"

