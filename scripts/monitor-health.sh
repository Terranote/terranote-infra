#!/bin/bash
# Script de monitoreo de salud para Terranote
# Verifica el estado de los servicios y envía alertas si es necesario

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
ADAPTER_URL="${ADAPTER_URL:-http://localhost:3000}"
CORE_URL="${CORE_URL:-http://localhost:8002}"
ADAPTER_HEALTH_ENDPOINT="${ADAPTER_URL}/health"
CORE_HEALTH_ENDPOINT="${CORE_URL}/api/v1/status"
LOG_FILE="${LOG_FILE:-/var/log/terranote-health.log}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Estado
ADAPTER_STATUS="unknown"
CORE_STATUS="unknown"
ADAPTER_DETAILS=""
CORE_DETAILS=""
EXIT_CODE=0

# Funciones de utilidad
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "${LOG_FILE}" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "${LOG_FILE}" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "${LOG_FILE}" 2>/dev/null || true
}

# Función para verificar health endpoint
check_health() {
    local name="$1"
    local url="$2"
    local response
    
    if response=$(curl -s -f -m 5 "${url}" 2>&1); then
        # Intentar parsear JSON si es posible
        if command -v jq >/dev/null 2>&1; then
            local status=$(echo "${response}" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")
            echo "${status}"
        else
            # Si no hay jq, buscar "ok" en la respuesta
            if echo "${response}" | grep -qi '"status".*"ok"'; then
                echo "ok"
            else
                echo "unknown"
            fi
        fi
    else
        echo "down"
    fi
}

# Función para obtener detalles del health check
get_health_details() {
    local url="$1"
    curl -s -f -m 5 "${url}" 2>/dev/null || echo "{}"
}

# Función para enviar alerta por email
send_email_alert() {
    local subject="$1"
    local body="$2"
    
    if [ -n "${ALERT_EMAIL}" ] && command -v mail >/dev/null 2>&1; then
        echo "${body}" | mail -s "${subject}" "${ALERT_EMAIL}" 2>/dev/null || true
    fi
}

# Función para enviar alerta por webhook
send_webhook_alert() {
    local message="$1"
    
    if [ -n "${WEBHOOK_URL}" ]; then
        local payload=$(cat <<EOF
{
  "text": "🚨 Terranote Health Alert",
  "attachments": [
    {
      "color": "danger",
      "text": "${message}",
      "ts": $(date +%s)
    }
  ]
}
EOF
        )
        curl -s -X POST -H "Content-Type: application/json" \
            -d "${payload}" "${WEBHOOK_URL}" >/dev/null 2>&1 || true
    fi
}

# Verificar adaptador
log_info "Verificando adaptador de Telegram..."
ADAPTER_STATUS=$(check_health "Adapter" "${ADAPTER_HEALTH_ENDPOINT}")
ADAPTER_DETAILS=$(get_health_details "${ADAPTER_HEALTH_ENDPOINT}")

if [ "${ADAPTER_STATUS}" = "ok" ]; then
    log_info "✅ Adaptador: OK"
elif [ "${ADAPTER_STATUS}" = "down" ]; then
    log_error "❌ Adaptador: DOWN"
    EXIT_CODE=1
    send_email_alert "Terranote Alert: Adaptador DOWN" "El adaptador de Telegram no responde en ${ADAPTER_URL}"
    send_webhook_alert "Adaptador de Telegram está DOWN en ${ADAPTER_URL}"
else
    log_warn "⚠️  Adaptador: Estado desconocido (${ADAPTER_STATUS})"
    EXIT_CODE=1
fi

# Verificar core
log_info "Verificando Core API..."
CORE_STATUS=$(check_health "Core" "${CORE_HEALTH_ENDPOINT}")
CORE_DETAILS=$(get_health_details "${CORE_HEALTH_ENDPOINT}")

if [ "${CORE_STATUS}" = "ok" ]; then
    log_info "✅ Core: OK"
elif [ "${CORE_STATUS}" = "down" ]; then
    log_error "❌ Core: DOWN"
    EXIT_CODE=1
    send_email_alert "Terranote Alert: Core DOWN" "El Core API no responde en ${CORE_URL}"
    send_webhook_alert "Core API está DOWN en ${CORE_URL}"
else
    log_warn "⚠️  Core: Estado desconocido (${CORE_STATUS})"
    EXIT_CODE=1
fi

# Verificar servicios systemd
log_info "Verificando servicios systemd..."
if systemctl is-active --quiet terranote-adapter-telegram 2>/dev/null; then
    log_info "✅ Servicio terranote-adapter-telegram: activo"
else
    log_error "❌ Servicio terranote-adapter-telegram: inactivo"
    EXIT_CODE=1
    send_webhook_alert "Servicio systemd terranote-adapter-telegram está inactivo"
fi

if systemctl is-active --quiet terranote-core 2>/dev/null; then
    log_info "✅ Servicio terranote-core: activo"
else
    log_error "❌ Servicio terranote-core: inactivo"
    EXIT_CODE=1
    send_webhook_alert "Servicio systemd terranote-core está inactivo"
fi

# Resumen
echo ""
log_info "=== Resumen ==="
echo "Adaptador: ${ADAPTER_STATUS}"
echo "Core: ${CORE_STATUS}"
echo ""

# Si hay problemas, mostrar detalles
if [ ${EXIT_CODE} -ne 0 ]; then
    if command -v jq >/dev/null 2>&1; then
        echo "Detalles del adaptador:"
        echo "${ADAPTER_DETAILS}" | jq '.' 2>/dev/null || echo "${ADAPTER_DETAILS}"
        echo ""
        echo "Detalles del core:"
        echo "${CORE_DETAILS}" | jq '.' 2>/dev/null || echo "${CORE_DETAILS}"
    fi
fi

exit ${EXIT_CODE}

