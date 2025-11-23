# Alerting con Prometheus y Alertmanager

Este documento explica cómo funciona el sistema de alertas con Prometheus y Alertmanager.

## Arquitectura

```
Aplicaciones → Prometheus (scrape metrics) → Alertmanager (evalúa reglas) → Notificaciones
```

1. **Prometheus** recolecta métricas de los servicios
2. **Prometheus** evalúa las reglas de alerta definidas en `alerts.yml`
3. Cuando una regla se activa, **Prometheus** envía la alerta a **Alertmanager**
4. **Alertmanager** agrupa, enruta y envía las notificaciones

## Reglas de Alerta

Las reglas están definidas en `alerts.yml` y se agrupan en:

### 1. Alertas de Servicios (`terranote_services`)

- **ServiceDown**: Servicio caído por más de 1 minuto (severity: critical)
- **HighErrorRate**: Tasa de errores > 5% por 5 minutos (severity: warning)
- **HighLatency**: Latencia P95 > 1s por 5 minutos (severity: warning)
- **CoreAPIUnavailable**: Más del 50% de llamadas al Core API fallan (severity: critical)
- **TelegramAPIUnavailable**: Más del 50% de llamadas a Telegram API fallan (severity: critical)
- **HighMessageFailureRate**: Más del 10% de mensajes fallan (severity: warning)

### 2. Alertas del Sistema (`terranote_system`)

- **HighMemoryUsage**: Uso de memoria > 500MB por 5 minutos (severity: warning)
- **HighCPUUsage**: Uso de CPU > 80% por 5 minutos (severity: warning)

## Configuración de Alertmanager

El archivo `alertmanager.yml` define:

### Rutas (Routes)

- **Critical alerts** → van al receptor `critical` (envía email a terranote@osm.lat)
- **Warning alerts** → van al receptor `default` (solo logging por ahora)

### Receptores (Receivers)

- **Critical**: Envía emails a `terranote@osm.lat` cuando hay alertas críticas
- **Default**: Logging básico (puedes agregar Slack, webhooks, etc. si lo necesitas)

### Configuración de Email (Ya Configurado)

El email está configurado para alertas críticas. Para configurarlo:

1. **Edita el archivo `.env`** en el directorio `prometheus/`:
   ```bash
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_FROM=terranote@osm.lat
   SMTP_USERNAME=terranote@osm.lat
   SMTP_PASSWORD=tu_contraseña_aquí
   SMTP_REQUIRE_TLS=true
   ```

2. **Para Gmail**, necesitas usar una "App Password":
   - Ve a https://myaccount.google.com/apppasswords
   - Genera una contraseña de aplicación
   - Úsala como `SMTP_PASSWORD`

3. **Reinicia Alertmanager**:
   ```bash
   docker-compose restart alertmanager
   ```

Las alertas críticas se enviarán automáticamente a `terranote@osm.lat`.

### Ejemplo: Configurar Slack (Opcional)

```yaml
receivers:
  - name: 'critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: 'CRITICAL Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Uso

### Configurar Email (Primera vez)

1. **Copia el archivo de ejemplo**:
   ```bash
   cd /home/terranote/terranote-infra/prometheus
   cp env.example .env
   ```

2. **Edita `.env`** y configura las credenciales SMTP:
   ```bash
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_FROM=terranote@osm.lat
   SMTP_USERNAME=terranote@osm.lat
   SMTP_PASSWORD=tu_app_password_aquí
   SMTP_REQUIRE_TLS=true
   ```

3. **Para Gmail**, necesitas una "App Password":
   - Ve a https://myaccount.google.com/apppasswords
   - Genera una contraseña de aplicación
   - Úsala como `SMTP_PASSWORD`

4. **Ejecuta el script de configuración** (opcional, verifica variables):
   ```bash
   bash setup-alertmanager.sh
   ```

### Iniciar los servicios

```bash
cd /home/terranote/terranote-infra/prometheus
docker-compose up -d
```

### Verificar estado

```bash
# Prometheus
docker-compose ps prometheus

# Alertmanager
docker-compose ps alertmanager

# Ver logs
docker-compose logs -f alertmanager
```

### Acceder a las interfaces

- **Prometheus UI**: http://localhost:9090
  - Ver alertas activas: http://localhost:9090/alerts
  - Ver reglas: http://localhost:9090/rules
  
- **Alertmanager UI**: http://localhost:9093
  - Ver alertas agrupadas
  - Ver historial de notificaciones
  - Silenciar alertas temporalmente

### Probar alertas

1. **Detener un servicio** para activar `ServiceDown`:
   ```bash
   sudo systemctl stop terranote-adapter-telegram
   ```

2. **Verificar en Prometheus**:
   - Ir a http://localhost:9090/alerts
   - Deberías ver la alerta `ServiceDown` activa

3. **Verificar en Alertmanager**:
   - Ir a http://localhost:9093
   - Deberías ver la alerta agrupada y enviada

### Silenciar alertas

Desde la UI de Alertmanager (http://localhost:9093):

1. Seleccionar la alerta
2. Click en "Silence"
3. Configurar duración del silencio
4. Guardar

O desde la línea de comandos:

```bash
# Silenciar una alerta específica
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "ServiceDown", "isRegex": false}
    ],
    "startsAt": "2025-11-21T10:00:00Z",
    "endsAt": "2025-11-21T12:00:00Z",
    "comment": "Maintenance window"
  }'
```

## Personalización

### Agregar nuevas reglas

Edita `alerts.yml` y agrega nuevas reglas en los grupos existentes o crea nuevos grupos:

```yaml
groups:
  - name: my_custom_alerts
    interval: 30s
    rules:
      - alert: MyCustomAlert
        expr: some_promql_expression > threshold
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Custom alert summary"
          description: "Detailed description of the alert"
```

Luego recarga la configuración de Prometheus:

```bash
# Opción 1: Reload via API (si web.enable-lifecycle está habilitado)
curl -X POST http://localhost:9090/-/reload

# Opción 2: Reiniciar el contenedor
docker-compose restart prometheus
```

### Modificar umbrales

Los umbrales están definidos en las expresiones PromQL. Por ejemplo:

- Error rate > 5%: Cambiar `> 0.05` a `> 0.10` para 10%
- Latency > 1s: Cambiar `> 1.0` a `> 2.0` para 2 segundos
- Memory > 500MB: Cambiar `> 500` a `> 1000` para 1GB

## Troubleshooting

### Las alertas no se activan

1. Verificar que las reglas estén cargadas:
   ```bash
   curl http://localhost:9090/api/v1/rules
   ```

2. Verificar que la expresión PromQL sea válida:
   - Ir a http://localhost:9090/graph
   - Probar la expresión manualmente

3. Verificar logs de Prometheus:
   ```bash
   docker-compose logs prometheus | grep -i error
   ```

### Las notificaciones no se envían

1. Verificar configuración de Alertmanager:
   ```bash
   docker-compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
   ```

2. Verificar logs de Alertmanager:
   ```bash
   docker-compose logs alertmanager
   ```

3. Verificar que los receptores estén configurados correctamente

### Ver estado de alertas

```bash
# Desde Prometheus
curl http://localhost:9090/api/v1/alerts | jq

# Desde Alertmanager
curl http://localhost:9093/api/v2/alerts | jq
```

## Referencias

- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

