# Prometheus Setup for Terranote

Configuración de Prometheus para scrapear métricas de los servicios de Terranote.

## Requisitos

- Docker y Docker Compose v2
- Acceso a los servicios que se van a monitorear:
  - `terranote-adapter-telegram` en `localhost:3000`
  - `terranote-core` en `localhost:8002`

## Configuración

### 1. Obtener Credenciales

El adaptador de Telegram requiere autenticación básica para el endpoint `/metrics`. Obtén la contraseña:

```bash
# En el servidor
grep METRICS_PASSWORD /home/terranote/terranote-adapter-telegram/.env
```

### 2. Configurar Variables de Entorno

Copia el archivo de ejemplo y completa los valores:

```bash
cp .env.example .env
```

Edita `.env` y agrega la contraseña de métricas:

```bash
METRICS_PASSWORD=tu_contraseña_aquí
```

### 3. Generar Configuración de Prometheus

La configuración de Prometheus necesita que la contraseña se inyecte en el archivo `prometheus.yml`. Usa `envsubst`:

```bash
# Generar prometheus.yml con las variables de entorno
envsubst < prometheus.yml.template > prometheus.yml
```

O si prefieres hacerlo manualmente, edita `prometheus.yml` y reemplaza `${METRICS_PASSWORD}` con la contraseña real.

### 4. Iniciar Prometheus

```bash
docker compose up -d
```

Prometheus estará disponible en `http://localhost:9090`.

## Verificar que Funciona

### 1. Verificar Targets

1. Abre `http://localhost:9090/targets` en tu navegador
2. Verifica que ambos targets estén "UP":
   - `terranote-adapter-telegram`
   - `terranote-core`

### 2. Explorar Métricas

1. Abre `http://localhost:9090/graph`
2. Escribe el nombre de una métrica en el campo de búsqueda, por ejemplo:
   - `terranote_adapter_telegram_http_requests_total`
   - `terranote_note_publication_attempts_total`
3. Ejecuta la consulta

### 3. Consultas Útiles

```promql
# Total de requests HTTP
sum(rate(terranote_adapter_telegram_http_requests_total[5m]))

# Requests por status code
sum by (status) (rate(terranote_adapter_telegram_http_requests_total[5m]))

# Latencia p95 del adaptador
histogram_quantile(0.95,
  rate(terranote_adapter_telegram_http_request_duration_seconds_bucket[5m])
)

# Intentos de publicación de notas
rate(terranote_note_publication_attempts_total[5m])

# Mensajes procesados
sum(rate(terranote_adapter_telegram_messages_processed_total[5m]))
```

## Estructura de Archivos

```
prometheus/
├── docker-compose.yml      # Docker Compose para Prometheus, Alertmanager y Grafana
├── prometheus.yml          # Configuración de Prometheus
├── alerts.yml              # Reglas de alerta para Prometheus
├── alertmanager.yml        # Configuración de Alertmanager
├── .env.example            # Ejemplo de variables de entorno
├── .env                    # Variables de entorno (no commitear)
├── README.md              # Esta documentación
├── README-alerting.md     # Documentación de alertas
└── grafana/              # Configuración de Grafana
    ├── provisioning/
    └── dashboards/
```

## Acceso desde el Host

Prometheus usa `host.docker.internal` para acceder a los servicios que corren en el host. Esto funciona en:
- Docker Desktop (Mac/Windows)
- Docker con `--add-host=host.docker.internal:host-gateway` (Linux)

Si estás en Linux y no funciona, puedes:
1. Usar la IP del host en lugar de `host.docker.internal`
2. O usar `network_mode: host` en el docker-compose (menos seguro)

## Retención de Datos

Por defecto, Prometheus retiene datos por 30 días. Puedes ajustar esto en `docker-compose.yml`:

```yaml
command:
  - '--storage.tsdb.retention.time=30d'  # Cambiar a 7d, 60d, etc.
```

## Troubleshooting

### Targets están DOWN

1. Verifica que los servicios estén corriendo:
   ```bash
   curl http://localhost:3000/health
   curl http://localhost:8002/metrics
   ```

2. Verifica la autenticación del adaptador:
   ```bash
   curl -u admin:TU_CONTRASEÑA http://localhost:3000/metrics
   ```

3. Verifica los logs de Prometheus:
   ```bash
   docker compose logs prometheus
   ```

### No se ven métricas

1. Asegúrate de que los servicios hayan procesado algunas requests
2. Verifica que los targets estén UP en `/targets`
3. Espera unos segundos después de que los targets estén UP

### Error de conexión a host.docker.internal

En Linux, puede que necesites agregar el host manualmente:

```bash
# Ver la IP del host
ip addr show docker0 | grep inet

# O usar network_mode: host en docker-compose.yml
```

## Grafana Dashboards

Grafana está incluido en el `docker-compose.yml` y se configura automáticamente.

### Acceder a Grafana

1. Inicia los servicios:
   ```bash
   docker compose up -d
   ```

2. Accede a Grafana:
   - URL: `http://localhost:3001`
   - Usuario: `admin`
   - Contraseña: `admin` (cambiar en producción)

3. El dashboard "Terranote Overview" se carga automáticamente.

### Dashboards Disponibles

- **Terranote Overview**: Dashboard principal con métricas de HTTP, APIs, mensajes y sistema

### Cambiar Contraseña de Grafana

1. Accede a Grafana: `http://localhost:3001`
2. Ve a Configuration → Users → Change Password
3. O modifica `GF_SECURITY_ADMIN_PASSWORD` en `docker-compose.yml`

## Alertmanager

Alertmanager está configurado para gestionar alertas. Ver [README-alerting.md](README-alerting.md) para más detalles.

### Acceder a Alertmanager

- **URL**: http://localhost:9093
- Ver alertas activas, historial y silenciar alertas

### Reglas de Alerta

Las reglas están definidas en `alerts.yml` e incluyen:
- Servicios caídos
- Alta tasa de errores
- Alta latencia
- APIs no disponibles
- Alto uso de recursos

## Próximos Pasos

- [x] Configurar Alertmanager para alertas
- [x] Crear reglas de alerta (ver `alerts.yml`)
- [ ] Configurar notificaciones (email, Slack, etc.) en `alertmanager.yml`
- [ ] Configurar retención de datos a largo plazo
- [ ] Cambiar contraseña por defecto de Grafana en producción

## Referencias

- [Documentación de Prometheus](https://prometheus.io/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Configuración de Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)

