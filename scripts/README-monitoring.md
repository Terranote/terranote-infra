# Script de Monitoreo de Salud

Script automatizado para verificar el estado de los servicios de Terranote y enviar alertas.

## Uso

### Ejecución Manual

```bash
# Ejecutar verificación
bash /home/terranote/terranote-infra/scripts/monitor-health.sh

# Con configuración personalizada
ADAPTER_URL=http://localhost:3000 \
CORE_URL=http://localhost:8002 \
bash scripts/monitor-health.sh
```

### Configuración

Variables de entorno:

```bash
# URLs de los servicios (por defecto: localhost)
export ADAPTER_URL=http://localhost:3000
export CORE_URL=http://localhost:8002

# Email para alertas (opcional)
export ALERT_EMAIL=admin@example.com

# Webhook para alertas (opcional, formato Slack)
export WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Archivo de log (por defecto: /var/log/terranote-health.log)
export LOG_FILE=/var/log/terranote-health.log
```

### Automatización con Cron

```bash
# Editar crontab
crontab -e

# Verificar cada 5 minutos
*/5 * * * * /home/terranote/terranote-infra/scripts/monitor-health.sh

# Verificar cada hora y enviar resumen
0 * * * * /home/terranote/terranote-infra/scripts/monitor-health.sh >> /var/log/terranote-health-summary.log 2>&1
```

### Automatización con systemd Timer (Recomendado)

1. Crear servicio: `/etc/systemd/system/terranote-health.service`

```ini
[Unit]
Description=Terranote Health Check
After=network.target

[Service]
Type=oneshot
User=terranote
Environment="ADAPTER_URL=http://localhost:3000"
Environment="CORE_URL=http://localhost:8002"
Environment="ALERT_EMAIL=admin@example.com"
Environment="WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
ExecStart=/home/terranote/terranote-infra/scripts/monitor-health.sh
StandardOutput=journal
StandardError=journal
```

2. Crear timer: `/etc/systemd/system/terranote-health.timer`

```ini
[Unit]
Description=Run Terranote Health Check Every 5 Minutes
Requires=terranote-health.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

3. Activar el timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable terranote-health.timer
sudo systemctl start terranote-health.timer

# Verificar
sudo systemctl status terranote-health.timer
sudo systemctl list-timers terranote-health.timer
```

## Alertas

### Email

Para enviar alertas por email, necesitas:
- `mail` command disponible
- Configurar `ALERT_EMAIL`

```bash
# Instalar mail (Debian/Ubuntu)
sudo apt-get install mailutils

# Configurar (opcional)
sudo dpkg-reconfigure postfix
```

### Webhook (Slack, Discord, etc.)

Para enviar alertas a Slack:

1. Crear un webhook en Slack: https://api.slack.com/messaging/webhooks
2. Configurar la variable:

```bash
export WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

Para Discord, usar formato similar pero con el endpoint de Discord.

## Salida

El script retorna:
- **Exit code 0**: Todos los servicios están OK
- **Exit code 1**: Al menos un servicio tiene problemas

### Logs

Los logs se escriben en:
- Archivo: `/var/log/terranote-health.log` (por defecto)
- Journald: Si se ejecuta como servicio systemd

### Ejemplo de Salida

```
[INFO] Verificando adaptador de Telegram...
[INFO] ✅ Adaptador: OK
[INFO] Verificando Core API...
[INFO] ✅ Core: OK
[INFO] Verificando servicios systemd...
[INFO] ✅ Servicio terranote-adapter-telegram: activo
[INFO] ✅ Servicio terranote-core: activo

[INFO] === Resumen ===
Adaptador: ok
Core: ok
```

## Integración con Prometheus

Este script puede usarse junto con Prometheus para alertas más avanzadas. Alternativamente, puedes usar el endpoint `/metrics` directamente con Prometheus Alertmanager.

## Troubleshooting

### Script no encuentra jq

Si `jq` no está instalado, el script funcionará pero con capacidades limitadas:

```bash
# Instalar jq (Debian/Ubuntu)
sudo apt-get install jq

# O usar el script sin jq (funciona pero menos detallado)
```

### Permisos de log

Si hay problemas escribiendo logs:

```bash
# Crear directorio de logs
sudo mkdir -p /var/log
sudo touch /var/log/terranote-health.log
sudo chown terranote:terranote /var/log/terranote-health.log
```

### Servicios no accesibles

Si los servicios no son accesibles desde el script:

1. Verificar que los servicios están corriendo
2. Verificar que las URLs son correctas
3. Verificar firewall/red

## Referencias

- [Runbooks de Operaciones](../docs/runbooks.md)
- [Health Endpoints](../../terranote-adapter-telegram/docs/accessing-endpoints.md)

