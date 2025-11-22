# Runbooks para Terranote

Guías operativas para tareas comunes de administración y troubleshooting de los servicios de Terranote.

## Tabla de Contenidos

- [Reinicio de Servicios](#reinicio-de-servicios)
- [Despliegue y Actualización](#despliegue-y-actualización)
- [Troubleshooting](#troubleshooting)
- [Verificación de Salud](#verificación-de-salud)
- [Monitoreo y Alertas](#monitoreo-y-alertas)

## Reinicio de Servicios

### Reinicio Individual

```bash
# Reiniciar adaptador de Telegram
sudo systemctl restart terranote-adapter-telegram

# Reiniciar Core API
sudo systemctl restart terranote-core
```

### Reinicio de Todos los Servicios

```bash
# Reiniciar ambos servicios
sudo systemctl restart terranote-adapter-telegram terranote-core

# Verificar que ambos estén corriendo
sudo systemctl status terranote-adapter-telegram terranote-core
```

### Reinicio con Verificación

```bash
# Reiniciar y verificar inmediatamente
sudo systemctl restart terranote-adapter-telegram
sleep 2
sudo systemctl status terranote-adapter-telegram --no-pager

# Verificar health check
curl -s http://localhost:3000/health | jq '.status'
```

### Reinicio Forzado (si el servicio no responde)

```bash
# Detener forzadamente
sudo systemctl stop terranote-adapter-telegram
sleep 2

# Matar procesos huérfanos (si existen)
sudo pkill -f "tsx src/server.ts" || true

# Iniciar de nuevo
sudo systemctl start terranote-adapter-telegram
```

## Despliegue y Actualización

### Proceso de Despliegue Completo

#### 1. Preparación

```bash
# Conectarse al servidor
ssh angoca@192.168.0.7

# Verificar estado actual
sudo systemctl status terranote-adapter-telegram terranote-core
```

#### 2. Actualizar Código

```bash
# Adaptador de Telegram
cd /home/terranote/terranote-adapter-telegram
git pull
npm install  # Si hay cambios en package.json

# Core API
cd /home/terranote/terranote-core
git pull
poetry install  # Si hay cambios en dependencias
```

#### 3. Verificar Configuración

```bash
# Verificar que los .env existen y tienen valores
ls -la /home/terranote/terranote-adapter-telegram/.env
ls -la /home/terranote/terranote-core/.env

# Verificar variables críticas (sin mostrar valores)
grep -E "^(TELEGRAM_BOT_TOKEN|CORE_API)" /home/terranote/terranote-adapter-telegram/.env | cut -d'=' -f1
```

#### 4. Reiniciar Servicios

```bash
# Reiniciar adaptador
sudo systemctl restart terranote-adapter-telegram

# Esperar unos segundos
sleep 3

# Reiniciar core
sudo systemctl restart terranote-core
```

#### 5. Verificación Post-Despliegue

```bash
# Verificar que los servicios están corriendo
sudo systemctl status terranote-adapter-telegram terranote-core --no-pager

# Verificar health checks
curl -s http://localhost:3000/health | jq
curl -s http://localhost:8002/api/v1/status | jq

# Verificar logs recientes (últimos 20 líneas)
sudo journalctl -u terranote-adapter-telegram -n 20 --no-pager
sudo journalctl -u terranote-core -n 20 --no-pager
```

### Actualización de Infraestructura (systemd)

```bash
# Actualizar archivos de servicio
cd /home/terranote/terranote-infra
git pull

# Reinstalar servicios (si hay cambios)
bash systemd/install-services.sh

# Reiniciar servicios
sudo systemctl restart terranote-adapter-telegram terranote-core
```

### Rollback (Revertir a Versión Anterior)

```bash
# Adaptador
cd /home/terranote/terranote-adapter-telegram
git log --oneline -10  # Ver commits recientes
git checkout <commit-hash-anterior>
npm install  # Si es necesario
sudo systemctl restart terranote-adapter-telegram

# Core
cd /home/terranote/terranote-core
git log --oneline -10
git checkout <commit-hash-anterior>
poetry install  # Si es necesario
sudo systemctl restart terranote-core
```

## Troubleshooting

### Servicio No Inicia

#### 1. Verificar Estado y Logs

```bash
# Ver estado detallado
sudo systemctl status terranote-adapter-telegram -l --no-pager

# Ver logs completos
sudo journalctl -u terranote-adapter-telegram -n 100 --no-pager
```

#### 2. Verificar Archivos y Permisos

```bash
# Verificar que el directorio existe
ls -la /home/terranote/terranote-adapter-telegram/

# Verificar permisos
ls -la /home/terranote/terranote-adapter-telegram/.env

# Verificar que el usuario terranote puede acceder
sudo -u terranote test -r /home/terranote/terranote-adapter-telegram/.env && echo "OK" || echo "ERROR"
```

#### 3. Verificar Dependencias

```bash
# Verificar Node.js
sudo -u terranote which node
sudo -u terranote node --version

# Verificar npm
sudo -u terranote which npm
sudo -u terranote npm --version

# Verificar Poetry (para Core)
sudo -u terranote which poetry
sudo -u terranote poetry --version
```

#### 4. Ejecutar Manualmente (para debugging)

```bash
# Como usuario terranote
sudo -u terranote bash -c "cd /home/terranote/terranote-adapter-telegram && npm start"
```

### Servicio Se Reinicia Constantemente

```bash
# Ver logs para encontrar el error
sudo journalctl -u terranote-adapter-telegram -f

# Ver cuántas veces se ha reiniciado
sudo systemctl status terranote-adapter-telegram | grep "Active:"

# Verificar configuración del servicio
cat /etc/systemd/system/terranote-adapter-telegram.service | grep Restart
```

### Errores de Conexión

#### Adaptador no puede conectar al Core

```bash
# Verificar que Core está corriendo
curl http://localhost:8002/api/v1/status

# Verificar conectividad desde el adaptador
sudo -u terranote curl http://localhost:8002/api/v1/status

# Verificar configuración
grep CORE_API_BASE_URL /home/terranote/terranote-adapter-telegram/.env
```

#### Core no puede conectar a OSM

```bash
# Verificar configuración de OSM
grep OSM_API /home/terranote/terranote-core/.env

# Probar conectividad
curl https://api.openstreetmap.org/api/0.6/capabilities
```

### Errores de Autenticación

#### Telegram Bot Token Inválido

```bash
# Verificar token en .env
grep TELEGRAM_BOT_TOKEN /home/terranote/terranote-adapter-telegram/.env | cut -c1-20

# Probar token con API de Telegram
TOKEN=$(grep TELEGRAM_BOT_TOKEN /home/terranote/terranote-adapter-telegram/.env | cut -d'=' -f2)
curl "https://api.telegram.org/bot${TOKEN}/getMe"
```

#### Core API Token Inválido

```bash
# Verificar token
grep CORE_API_TOKEN /home/terranote/terranote-adapter-telegram/.env | cut -c1-20
```

### Problemas de Memoria/CPU

```bash
# Ver uso de recursos
sudo systemctl status terranote-adapter-telegram | grep -E "Memory|CPU"

# Ver procesos
ps aux | grep -E "tsx|uvicorn" | grep -v grep

# Ver uso de memoria detallado
sudo journalctl -u terranote-adapter-telegram | grep -i "memory\|heap" | tail -20
```

### Logs Llenos o Rotación

```bash
# Ver tamaño de logs de journald
sudo journalctl --disk-usage

# Limpiar logs antiguos (mantener últimos 7 días)
sudo journalctl --vacuum-time=7d

# Ver configuración de retención
cat /etc/systemd/journald.conf | grep -E "SystemMaxUse|MaxRetentionSec"
```

## Verificación de Salud

### Health Checks Rápidos

```bash
# Adaptador
curl -s http://localhost:3000/health | jq '.status'

# Core
curl -s http://localhost:8002/api/v1/status | jq
```

### Health Checks Detallados

```bash
# Ver estado completo del adaptador
curl -s http://localhost:3000/health | jq

# Verificar dependencias
curl -s http://localhost:3000/health | jq '.dependencies'

# Verificar uptime
curl -s http://localhost:3000/health | jq '.uptime'
```

### Verificación desde Internet

```bash
# Health check público
curl -s https://terranote-tg.osm.lat/health | jq

# Métricas (requiere autenticación)
curl -u admin:TU_CONTRASEÑA https://terranote-tg-metrics.osm.lat/metrics | head -20
```

## Monitoreo y Alertas

### Ver Métricas en Tiempo Real

```bash
# Ver métricas HTTP
curl -u admin:TU_CONTRASEÑA http://localhost:3000/metrics | grep http_requests_total

# Ver métricas del Core API
curl -u admin:TU_CONTRASEÑA http://localhost:3000/metrics | grep core_api_calls_total

# Ver métricas de mensajes
curl -u admin:TU_CONTRASEÑA http://localhost:3000/metrics | grep messages_
```

### Ver Logs en Tiempo Real

```bash
# Seguir logs del adaptador
sudo journalctl -u terranote-adapter-telegram -f

# Seguir logs del core
sudo journalctl -u terranote-core -f

# Seguir ambos
sudo journalctl -u terranote-adapter-telegram -u terranote-core -f
```

### Filtrar Logs por Nivel

```bash
# Solo errores
sudo journalctl -u terranote-adapter-telegram -p err

# Errores y warnings
sudo journalctl -u terranote-adapter-telegram -p warning

# Última hora
sudo journalctl -u terranote-adapter-telegram --since "1 hour ago"
```

### Alertas Básicas (Script de Monitoreo)

Crear un script de monitoreo simple:

```bash
#!/bin/bash
# /usr/local/bin/check-terranote.sh

ADAPTER_HEALTH=$(curl -s http://localhost:3000/health | jq -r '.status')
CORE_HEALTH=$(curl -s http://localhost:8002/api/v1/status | jq -r '.status // "unknown"')

if [ "$ADAPTER_HEALTH" != "ok" ] || [ "$CORE_HEALTH" != "ok" ]; then
    echo "ALERT: Services unhealthy"
    echo "Adapter: $ADAPTER_HEALTH"
    echo "Core: $CORE_HEALTH"
    # Enviar alerta (email, webhook, etc.)
    exit 1
fi

exit 0
```

Agregar a cron:

```bash
# Verificar cada 5 minutos
*/5 * * * * /usr/local/bin/check-terranote.sh
```

## Comandos Útiles de Referencia Rápida

```bash
# Estado de servicios
sudo systemctl status terranote-adapter-telegram terranote-core

# Reiniciar servicios
sudo systemctl restart terranote-adapter-telegram terranote-core

# Ver logs recientes
sudo journalctl -u terranote-adapter-telegram -n 50
sudo journalctl -u terranote-core -n 50

# Health checks
curl http://localhost:3000/health | jq
curl http://localhost:8002/api/v1/status | jq

# Ver métricas
curl -u admin:TU_CONTRASEÑA http://localhost:3000/metrics | grep terranote_adapter_telegram

# Ver procesos
ps aux | grep -E "tsx|uvicorn"

# Ver puertos en uso
sudo lsof -i :3000
sudo lsof -i :8002
```

## Referencias

- [Systemd Services README](../systemd/README.md)
- [Monitoring Documentation](../docs/monitoring.md)
- [Logging Best Practices](../../terranote-adapter-telegram/docs/logging.md)

