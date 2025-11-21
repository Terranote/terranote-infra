#!/bin/bash
# Script para configurar Prometheus con las credenciales del servidor

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 Configurando Prometheus para Terranote..."

# Verificar que existe prometheus.yml
if [ ! -f "prometheus.yml" ]; then
    echo "❌ Error: prometheus.yml no encontrado"
    exit 1
fi

# Obtener la contraseña directamente del servidor (si estamos en el servidor)
# O usar la variable de entorno si está disponible
if [ -z "$METRICS_PASSWORD" ]; then
    if [ -f "/home/terranote/terranote-adapter-telegram/.env" ]; then
        echo "🔍 Obteniendo contraseña del servidor..."
        METRICS_PASSWORD=$(grep METRICS_PASSWORD /home/terranote/terranote-adapter-telegram/.env | cut -d'=' -f2)
    elif [ -f ".env" ]; then
        echo "📋 Cargando contraseña de .env..."
        source .env
    else
        echo "❌ Error: No se pudo obtener METRICS_PASSWORD"
        echo "💡 Opciones:"
        echo "   1. Crear .env con METRICS_PASSWORD=tu_contraseña"
        echo "   2. Ejecutar: export METRICS_PASSWORD=tu_contraseña"
        echo "   3. Obtener del servidor: grep METRICS_PASSWORD /home/terranote/terranote-adapter-telegram/.env"
        exit 1
    fi
fi

if [ -z "$METRICS_PASSWORD" ] || [ "$METRICS_PASSWORD" = "your_metrics_password_here" ]; then
    echo "❌ Error: METRICS_PASSWORD no está configurado"
    exit 1
fi

# Crear backup del prometheus.yml original si no existe
if [ ! -f "prometheus.yml.backup" ]; then
    echo "💾 Creando backup de prometheus.yml..."
    cp prometheus.yml prometheus.yml.backup
fi

# Reemplazar la variable en prometheus.yml
echo "🔐 Inyectando credenciales en prometheus.yml..."
# Escapar caracteres especiales para sed
ESCAPED_PASSWORD=$(printf '%s\n' "$METRICS_PASSWORD" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i.tmp "s/\${METRICS_PASSWORD}/$ESCAPED_PASSWORD/g" prometheus.yml 2>/dev/null || \
sed -i "s/\${METRICS_PASSWORD}/$ESCAPED_PASSWORD/g" prometheus.yml
rm -f prometheus.yml.tmp

echo "✅ Configuración completada!"
echo ""
echo "📊 Para iniciar Prometheus:"
echo "   docker compose up -d"
echo ""
echo "🌐 Accede a Prometheus en:"
echo "   http://localhost:9090"
