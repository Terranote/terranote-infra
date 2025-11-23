#!/bin/bash
# Script para configurar Alertmanager con variables de entorno
# Uso: bash setup-alertmanager.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Configuración de Alertmanager ==="
echo ""

# Verificar que existe .env
if [ ! -f .env ]; then
    echo "⚠️  Archivo .env no encontrado. Creando desde env.example..."
    if [ -f env.example ]; then
        cp env.example .env
        echo "✓ Archivo .env creado. Por favor, edítalo con tus credenciales SMTP."
        echo ""
        echo "Variables necesarias:"
        echo "  - SMTP_HOST (ej: smtp.gmail.com)"
        echo "  - SMTP_PORT (ej: 587)"
        echo "  - SMTP_FROM (ej: terranote@osm.lat)"
        echo "  - SMTP_USERNAME (ej: terranote@osm.lat)"
        echo "  - SMTP_PASSWORD (contraseña o app password)"
        echo "  - SMTP_REQUIRE_TLS (true/false)"
        echo ""
        exit 1
    else
        echo "❌ Error: No se encontró env.example"
        exit 1
    fi
fi

# Cargar variables de entorno
set -a
source .env
set +a

# Verificar variables requeridas
REQUIRED_VARS=("SMTP_HOST" "SMTP_PORT" "SMTP_FROM" "SMTP_USERNAME" "SMTP_PASSWORD")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Faltan las siguientes variables en .env:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Por favor, edita .env y agrega estas variables."
    exit 1
fi

echo "✓ Variables de entorno cargadas"
echo ""
echo "Configuración SMTP:"
echo "  Host: $SMTP_HOST"
echo "  Port: $SMTP_PORT"
echo "  From: $SMTP_FROM"
echo "  Username: $SMTP_USERNAME"
echo "  Require TLS: ${SMTP_REQUIRE_TLS:-true}"
echo ""

# Verificar que alertmanager.yml existe
if [ ! -f alertmanager.yml ]; then
    echo "❌ Error: alertmanager.yml no encontrado"
    exit 1
fi

echo "✓ Configuración lista"
echo ""
echo "Para iniciar Alertmanager:"
echo "  docker-compose up -d alertmanager"
echo ""
echo "Para verificar que funciona, puedes probar enviando una alerta de prueba:"
echo "  curl -X POST http://localhost:9093/api/v1/alerts -d '[{\"labels\":{\"alertname\":\"test\"}}]'"
echo ""

