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

# Obtener la contraseña del adapter-telegram directamente del servidor (si estamos en el servidor)
# O usar la variable de entorno si está disponible
if [ -z "$METRICS_PASSWORD" ]; then
    if [ -f "/home/terranote/terranote-adapter-telegram/.env" ]; then
        echo "🔍 Obteniendo contraseña del adapter-telegram del servidor..."
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

# Obtener la contraseña de terranote-core (opcional)
CORE_METRICS_PASSWORD=""
if [ -z "$CORE_METRICS_PASSWORD" ]; then
    if [ -f "/home/terranote/terranote-core/.env" ]; then
        echo "🔍 Verificando si terranote-core tiene autenticación configurada..."
        CORE_METRICS_PASSWORD=$(grep "^METRICS_PASSWORD=" /home/terranote/terranote-core/.env 2>/dev/null | cut -d'=' -f2 || echo "")
    fi
fi

# Crear backup del prometheus.yml original si no existe
if [ ! -f "prometheus.yml.backup" ]; then
    echo "💾 Creando backup de prometheus.yml..."
    cp prometheus.yml prometheus.yml.backup
fi

# Reemplazar las variables en prometheus.yml
echo "🔐 Inyectando credenciales en prometheus.yml..."
# Escapar caracteres especiales para sed
ESCAPED_PASSWORD=$(printf '%s\n' "$METRICS_PASSWORD" | sed 's/[[\.*^$()+?{|]/\\&/g')
sed -i.tmp "s/\${METRICS_PASSWORD}/$ESCAPED_PASSWORD/g" prometheus.yml 2>/dev/null || \
sed -i "s/\${METRICS_PASSWORD}/$ESCAPED_PASSWORD/g" prometheus.yml
rm -f prometheus.yml.tmp

# Si terranote-core tiene autenticación configurada, habilitarla en prometheus.yml
if [ -n "$CORE_METRICS_PASSWORD" ]; then
    echo "🔐 Habilitando autenticación para terranote-core en prometheus.yml..."
    ESCAPED_CORE_PASSWORD=$(printf '%s\n' "$CORE_METRICS_PASSWORD" | sed 's/[[\.*^$()+?{|]/\\&/g')
    # Reemplazar las líneas comentadas de basic_auth con las descomentadas
    sed -i.tmp "s|# Basic auth is optional - uncomment if METRICS_USERNAME and METRICS_PASSWORD are configured|# Basic auth enabled for terranote-core|g" prometheus.yml
    sed -i.tmp "s|# basic_auth:|basic_auth:|g" prometheus.yml
    sed -i.tmp "s|#   username: 'admin'|  username: 'admin'|g" prometheus.yml
    sed -i.tmp "s|#   password: '\${CORE_METRICS_PASSWORD}'|  password: '$ESCAPED_CORE_PASSWORD'|g" prometheus.yml
    rm -f prometheus.yml.tmp
    echo "✅ Autenticación habilitada para terranote-core"
else
    echo "ℹ️  terranote-core no tiene autenticación configurada (opcional)"
fi

echo "✅ Configuración completada!"
echo ""
echo "📊 Para iniciar Prometheus:"
echo "   docker compose up -d"
echo ""
echo "🌐 Accede a Prometheus en:"
echo "   http://localhost:9090"
