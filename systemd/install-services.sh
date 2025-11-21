#!/usr/bin/env bash
# Script para instalar los servicios systemd de Terranote
# Ejecutar con: bash install-services.sh

set -euo pipefail

echo "=== Instalación de servicios systemd para Terranote ==="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar que estamos en el directorio correcto
if [ ! -f "systemd/terranote-adapter-telegram.service" ]; then
    echo -e "${RED}Error: No se encontraron los archivos de servicio.${NC}"
    echo "Ejecuta este script desde el directorio terranote-infra"
    exit 1
fi

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
sudo cp systemd/*.service /etc/systemd/system/
echo -e "${GREEN}✓ Archivos copiados${NC}"
echo ""

echo -e "${YELLOW}3. Recargando configuración de systemd...${NC}"
sudo systemctl daemon-reload
echo -e "${GREEN}✓ systemd recargado${NC}"
echo ""

echo -e "${YELLOW}4. Habilitando servicios para inicio automático...${NC}"
sudo systemctl enable terranote-adapter-telegram
sudo systemctl enable terranote-core
echo -e "${GREEN}✓ Servicios habilitados${NC}"
echo ""

echo -e "${YELLOW}5. Iniciando servicios...${NC}"
sudo systemctl start terranote-adapter-telegram
sudo systemctl start terranote-core
echo -e "${GREEN}✓ Servicios iniciados${NC}"
echo ""

echo -e "${YELLOW}6. Verificando estado...${NC}"
echo ""
sudo systemctl status terranote-adapter-telegram --no-pager -l | head -10
echo ""
sudo systemctl status terranote-core --no-pager -l | head -10
echo ""

echo -e "${GREEN}=== Instalación completada ===${NC}"
echo ""
echo "Para ver los logs:"
echo "  sudo journalctl -u terranote-adapter-telegram -f"
echo "  sudo journalctl -u terranote-core -f"
echo ""
echo "Para gestionar los servicios:"
echo "  sudo systemctl status terranote-adapter-telegram"
echo "  sudo systemctl restart terranote-adapter-telegram"
echo "  sudo systemctl stop terranote-adapter-telegram"

