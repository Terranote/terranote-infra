#!/usr/bin/env bash
# Script para instalar los servicios systemd de Terranote
# Ejecutar con: bash systemd/install-services.sh
# Requiere permisos sudo

set -euo pipefail

# Verificar que se puede ejecutar sudo
if ! sudo -n true 2>/dev/null; then
    echo "Este script requiere permisos sudo."
    echo "Se te pedirá la contraseña cuando sea necesario."
    echo ""
fi

echo "=== Instalación de servicios systemd para Terranote ==="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que estamos en el directorio correcto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$INFRA_DIR/systemd/terranote-adapter-telegram.service" ]; then
    echo -e "${RED}Error: No se encontraron los archivos de servicio.${NC}"
    echo "Ejecuta este script desde el directorio terranote-infra o desde systemd/"
    exit 1
fi

# Cambiar al directorio de infra si es necesario
cd "$INFRA_DIR"

echo -e "${YELLOW}1. Deteniendo procesos manuales (si existen)...${NC}"

# Detener procesos manuales del adaptador
if [ -f "/home/terranote/adapter.pid" ]; then
    ADAPTER_PID=$(cat /home/terranote/adapter.pid 2>/dev/null || echo "")
    if [ -n "$ADAPTER_PID" ] && kill -0 "$ADAPTER_PID" 2>/dev/null; then
        echo "  Deteniendo adaptador (PID: $ADAPTER_PID)..."
        kill "$ADAPTER_PID" 2>/dev/null || true
        sleep 2
    fi
fi

# Detener procesos manuales del core
if [ -f "/home/terranote/core.pid" ]; then
    CORE_PID=$(cat /home/terranote/core.pid 2>/dev/null || echo "")
    if [ -n "$CORE_PID" ] && kill -0 "$CORE_PID" 2>/dev/null; then
        echo "  Deteniendo core (PID: $CORE_PID)..."
        kill "$CORE_PID" 2>/dev/null || true
        sleep 2
    fi
fi

# Detener cualquier proceso restante
pkill -f "tsx.*server.ts" 2>/dev/null || true
pkill -f "uvicorn.*app.main" 2>/dev/null || true
sleep 2

echo -e "${GREEN}✓ Procesos manuales detenidos${NC}"
echo ""

echo -e "${YELLOW}2. Copiando archivos de servicio a /etc/systemd/system/...${NC}"
if [ "$EUID" -eq 0 ]; then
    cp systemd/*.service /etc/systemd/system/
    [ -f systemd/terranote-backup.timer ] && cp systemd/terranote-backup.timer /etc/systemd/system/ || true
else
    sudo cp systemd/*.service /etc/systemd/system/
    [ -f systemd/terranote-backup.timer ] && sudo cp systemd/terranote-backup.timer /etc/systemd/system/ || true
fi
echo -e "${GREEN}✓ Archivos copiados${NC}"
echo ""

echo -e "${YELLOW}3. Recargando configuración de systemd...${NC}"
if [ "$EUID" -eq 0 ]; then
    systemctl daemon-reload
else
    sudo systemctl daemon-reload
fi
echo -e "${GREEN}✓ systemd recargado${NC}"
echo ""

echo -e "${YELLOW}4. Habilitando servicios para inicio automático...${NC}"
if [ "$EUID" -eq 0 ]; then
    systemctl enable terranote-adapter-telegram
    systemctl enable terranote-core
    [ -f systemd/terranote-adapter-whatsapp.service ] && systemctl enable terranote-adapter-whatsapp || true
    [ -f systemd/terranote-backup.timer ] && systemctl enable terranote-backup.timer || true
else
    sudo systemctl enable terranote-adapter-telegram
    sudo systemctl enable terranote-core
    [ -f systemd/terranote-adapter-whatsapp.service ] && sudo systemctl enable terranote-adapter-whatsapp || true
    [ -f systemd/terranote-backup.timer ] && sudo systemctl enable terranote-backup.timer || true
fi
echo -e "${GREEN}✓ Servicios habilitados${NC}"
echo ""

echo -e "${YELLOW}5. Iniciando servicios...${NC}"
if [ "$EUID" -eq 0 ]; then
    systemctl start terranote-adapter-telegram
    systemctl start terranote-core
    [ -f systemd/terranote-adapter-whatsapp.service ] && systemctl start terranote-adapter-whatsapp || true
    [ -f systemd/terranote-backup.timer ] && systemctl start terranote-backup.timer || true
else
    sudo systemctl start terranote-adapter-telegram
    sudo systemctl start terranote-core
    [ -f systemd/terranote-adapter-whatsapp.service ] && sudo systemctl start terranote-adapter-whatsapp || true
    [ -f systemd/terranote-backup.timer ] && sudo systemctl start terranote-backup.timer || true
fi
echo -e "${GREEN}✓ Servicios iniciados${NC}"
echo ""

echo -e "${YELLOW}6. Verificando estado...${NC}"
echo ""
if [ "$EUID" -eq 0 ]; then
    systemctl status terranote-adapter-telegram --no-pager -l | head -10
    echo ""
    systemctl status terranote-core --no-pager -l | head -10
    [ -f systemd/terranote-adapter-whatsapp.service ] && (echo ""; systemctl status terranote-adapter-whatsapp --no-pager -l | head -10) || true
else
    sudo systemctl status terranote-adapter-telegram --no-pager -l | head -10
    echo ""
    sudo systemctl status terranote-core --no-pager -l | head -10
    [ -f systemd/terranote-adapter-whatsapp.service ] && (echo ""; sudo systemctl status terranote-adapter-whatsapp --no-pager -l | head -10) || true
fi
echo ""

echo -e "${GREEN}=== Instalación completada ===${NC}"
echo ""
echo "Para ver los logs:"
echo "  sudo journalctl -u terranote-adapter-telegram -f"
echo "  sudo journalctl -u terranote-core -f"
[ -f systemd/terranote-adapter-whatsapp.service ] && echo "  sudo journalctl -u terranote-adapter-whatsapp -f" || true
echo ""
echo "Para gestionar los servicios:"
echo "  sudo systemctl status terranote-adapter-telegram"
echo "  sudo systemctl restart terranote-adapter-telegram"
echo "  sudo systemctl stop terranote-adapter-telegram"
[ -f systemd/terranote-adapter-whatsapp.service ] && echo "  sudo systemctl status terranote-adapter-whatsapp" || true
[ -f systemd/terranote-backup.timer ] && echo "" && echo "Para gestionar el backup automático:" && echo "  sudo systemctl status terranote-backup.timer" && echo "  sudo systemctl list-timers terranote-backup.timer" || true

