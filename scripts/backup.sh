#!/bin/bash
# Script de backup automatizado para Terranote
# Hace backup de configuración, logs y datos importantes

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
BACKUP_BASE_DIR="${BACKUP_BASE_DIR:-/home/terranote/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_BASE_DIR}/terranote_${TIMESTAMP}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

# Directorios a respaldar
TERRANOTE_HOME="/home/terranote"
ADAPTER_DIR="${TERRANOTE_HOME}/terranote-adapter-telegram"
CORE_DIR="${TERRANOTE_HOME}/terranote-core"
INFRA_DIR="${TERRANOTE_HOME}/terranote-infra"
SYSTEMD_DIR="/etc/systemd/system"

# Funciones de utilidad
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Verificar que se ejecuta como usuario apropiado
if [ "$EUID" -eq 0 ]; then
    log_warn "Ejecutando como root. Algunos archivos pueden no ser accesibles."
fi

# Crear directorio de backup
log_info "Creando directorio de backup: ${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}"

# Función para hacer backup de un archivo
backup_file() {
    local source_file="$1"
    local dest_dir="$2"
    local dest_file="${dest_dir}/$(basename "${source_file}")"
    
    if [ -f "${source_file}" ]; then
        log_info "Respaldando: ${source_file}"
        mkdir -p "${dest_dir}"
        # Copiar preservando permisos si es posible
        if [ -r "${source_file}" ]; then
            cp "${source_file}" "${dest_file}" 2>/dev/null || sudo cp "${source_file}" "${dest_file}"
        else
            log_warn "No se puede leer: ${source_file}"
        fi
    else
        log_warn "Archivo no encontrado: ${source_file}"
    fi
}

# Función para hacer backup de un directorio
backup_directory() {
    local source_dir="$1"
    local dest_dir="$2"
    
    if [ -d "${source_dir}" ]; then
        log_info "Respaldando directorio: ${source_dir}"
        mkdir -p "${dest_dir}"
        # Copiar preservando estructura
        if [ -r "${source_dir}" ]; then
            cp -r "${source_dir}"/* "${dest_dir}/" 2>/dev/null || sudo cp -r "${source_dir}"/* "${dest_dir}/" 2>/dev/null || true
        else
            log_warn "No se puede leer directorio: ${source_dir}"
        fi
    else
        log_warn "Directorio no encontrado: ${source_dir}"
    fi
}

# 1. Backup de archivos de configuración (.env)
log_info "=== Respaldando archivos de configuración ==="
backup_file "${ADAPTER_DIR}/.env" "${BACKUP_DIR}/config/adapter"
backup_file "${CORE_DIR}/.env" "${BACKUP_DIR}/config/core"

# 2. Backup de configuración de systemd
log_info "=== Respaldando configuración de systemd ==="
if [ -f "${SYSTEMD_DIR}/terranote-adapter-telegram.service" ]; then
    backup_file "${SYSTEMD_DIR}/terranote-adapter-telegram.service" "${BACKUP_DIR}/systemd"
fi
if [ -f "${SYSTEMD_DIR}/terranote-core.service" ]; then
    backup_file "${SYSTEMD_DIR}/terranote-core.service" "${BACKUP_DIR}/systemd"
fi

# 3. Backup de logs de journald
log_info "=== Respaldando logs de journald ==="
JOURNAL_LOG_DIR="${BACKUP_DIR}/logs/journald"
mkdir -p "${JOURNAL_LOG_DIR}"

# Exportar logs del adaptador
if sudo journalctl -u terranote-adapter-telegram --no-pager >/dev/null 2>&1; then
    log_info "Exportando logs del adaptador..."
    sudo journalctl -u terranote-adapter-telegram --no-pager > "${JOURNAL_LOG_DIR}/adapter.log" 2>&1 || true
    sudo journalctl -u terranote-adapter-telegram --since "7 days ago" --no-pager > "${JOURNAL_LOG_DIR}/adapter_last_7days.log" 2>&1 || true
fi

# Exportar logs del core
if sudo journalctl -u terranote-core --no-pager >/dev/null 2>&1; then
    log_info "Exportando logs del core..."
    sudo journalctl -u terranote-core --no-pager > "${JOURNAL_LOG_DIR}/core.log" 2>&1 || true
    sudo journalctl -u terranote-core --since "7 days ago" --no-pager > "${JOURNAL_LOG_DIR}/core_last_7days.log" 2>&1 || true
fi

# 4. Backup de configuración de infraestructura (sin secrets)
log_info "=== Respaldando configuración de infraestructura ==="
if [ -d "${INFRA_DIR}" ]; then
    INFRA_BACKUP_DIR="${BACKUP_DIR}/infra"
    mkdir -p "${INFRA_BACKUP_DIR}"
    
    # Copiar archivos de configuración importantes (excluyendo .env y secrets)
    if [ -d "${INFRA_DIR}/systemd" ]; then
        cp -r "${INFRA_DIR}/systemd" "${INFRA_BACKUP_DIR}/" 2>/dev/null || true
    fi
    if [ -d "${INFRA_DIR}/prometheus" ]; then
        # Copiar prometheus.yml pero no .env
        mkdir -p "${INFRA_BACKUP_DIR}/prometheus"
        cp "${INFRA_DIR}/prometheus/prometheus.yml" "${INFRA_BACKUP_DIR}/prometheus/" 2>/dev/null || true
        cp "${INFRA_DIR}/prometheus/docker-compose.yml" "${INFRA_BACKUP_DIR}/prometheus/" 2>/dev/null || true
    fi
    if [ -d "${INFRA_DIR}/docs" ]; then
        cp -r "${INFRA_DIR}/docs" "${INFRA_BACKUP_DIR}/" 2>/dev/null || true
    fi
fi

# 5. Backup de datos de Prometheus (si está corriendo)
log_info "=== Verificando datos de Prometheus ==="
if docker ps --format '{{.Names}}' | grep -q "terranote-prometheus"; then
    PROMETHEUS_BACKUP_DIR="${BACKUP_DIR}/prometheus-data"
    mkdir -p "${PROMETHEUS_BACKUP_DIR}"
    log_info "Prometheus está corriendo. Respaldando datos..."
    
    # Exportar configuración de Prometheus desde el contenedor
    docker exec terranote-prometheus cat /etc/prometheus/prometheus.yml > "${PROMETHEUS_BACKUP_DIR}/prometheus.yml" 2>/dev/null || true
    
    log_warn "Nota: Los datos de métricas históricas no se respaldan por defecto (pueden ser grandes)."
    log_warn "Para respaldar datos completos, usar: docker exec terranote-prometheus tar czf - /prometheus > prometheus-data.tar.gz"
fi

# 6. Crear archivo de información del backup
log_info "=== Creando archivo de información ==="
INFO_FILE="${BACKUP_DIR}/backup_info.txt"
cat > "${INFO_FILE}" <<EOF
Backup de Terranote
===================

Fecha: $(date)
Hostname: $(hostname)
Usuario: $(whoami)

Contenido del backup:
- Configuración (.env files)
- Archivos de servicio systemd
- Logs de journald (últimos 7 días y completos)
- Configuración de infraestructura
- Datos de Prometheus (si aplica)

Servicios:
- terranote-adapter-telegram: $(systemctl is-active terranote-adapter-telegram 2>/dev/null || echo "unknown")
- terranote-core: $(systemctl is-active terranote-core 2>/dev/null || echo "unknown")

Versiones:
- Node.js: $(node --version 2>/dev/null || echo "N/A")
- Python: $(python3 --version 2>/dev/null || echo "N/A")
- Poetry: $(poetry --version 2>/dev/null || echo "N/A")

Tamaño del backup:
$(du -sh "${BACKUP_DIR}" 2>/dev/null || echo "N/A")
EOF

# 7. Comprimir backup
log_info "=== Comprimiendo backup ==="
BACKUP_ARCHIVE="${BACKUP_BASE_DIR}/terranote_${TIMESTAMP}.tar.gz"
cd "${BACKUP_BASE_DIR}"
tar czf "${BACKUP_ARCHIVE}" "terranote_${TIMESTAMP}" 2>/dev/null || {
    log_error "Error al comprimir backup"
    exit 1
}

# Eliminar directorio sin comprimir para ahorrar espacio
rm -rf "terranote_${TIMESTAMP}"

log_info "Backup comprimido: ${BACKUP_ARCHIVE}"
log_info "Tamaño: $(du -h "${BACKUP_ARCHIVE}" | cut -f1)"

# 8. Limpiar backups antiguos
log_info "=== Limpiando backups antiguos (más de ${RETENTION_DAYS} días) ==="
find "${BACKUP_BASE_DIR}" -name "terranote_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
REMAINING=$(find "${BACKUP_BASE_DIR}" -name "terranote_*.tar.gz" -type f | wc -l)
log_info "Backups restantes: ${REMAINING}"

# 9. Resumen final
log_info "=== Resumen del backup ==="
echo "Archivo: ${BACKUP_ARCHIVE}"
echo "Tamaño: $(du -h "${BACKUP_ARCHIVE}" | cut -f1)"
echo "Ubicación: ${BACKUP_BASE_DIR}"
echo ""
log_info "✅ Backup completado exitosamente"

# Opcional: Mostrar cómo restaurar
cat <<EOF

Para restaurar este backup:
  1. Extraer: tar xzf ${BACKUP_ARCHIVE}
  2. Copiar .env files: cp backup/config/adapter/.env ${ADAPTER_DIR}/.env
  3. Copiar .env files: cp backup/config/core/.env ${CORE_DIR}/.env
  4. Copiar systemd: sudo cp backup/systemd/*.service ${SYSTEMD_DIR}/
  5. Recargar systemd: sudo systemctl daemon-reload
  6. Reiniciar servicios: sudo systemctl restart terranote-adapter-telegram terranote-core

EOF

