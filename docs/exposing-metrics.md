# Exponer Métricas Públicamente con Cloudflare Tunnel

Esta guía explica cómo exponer el endpoint de métricas del adaptador de Telegram públicamente usando un subdominio de `osm.lat` a través de Cloudflare Tunnel.

## Consideraciones de Seguridad

⚠️ **IMPORTANTE**: Las métricas pueden contener información sensible sobre el sistema. Se recomienda:

1. **Autenticación básica**: Configurar usuario/contraseña para el endpoint `/metrics`
2. **Solo exponer `/health`**: Si no necesitas métricas detalladas, exponer solo el health check
3. **Firewall/IP whitelist**: Restringir acceso por IP si es posible

## Opción 1: Exponer `/health` (Recomendado para monitoreo básico)

El endpoint `/health` es más seguro porque no expone métricas detalladas.

### 1. Configurar subdominio en Cloudflare DNS

1. Ir a Cloudflare Dashboard → DNS
2. Agregar registro CNAME:
   - **Nombre**: `terranote-tg-health.osm.lat` (o el nombre que prefieras)
   - **Target**: `1b718247-fe2d-4391-84c0-819c1501e6c2.cfargotunnel.com`
   - **Proxy**: Activado (naranja)

### 2. Actualizar configuración de cloudflared

Editar `/etc/cloudflared/config.yml`:

```yaml
tunnel: 1b718247-fe2d-4391-84c0-819c1501e6c2
credentials-file: /root/.cloudflared/1b718247-fe2d-4391-84c0-819c1501e6c2.json
warp-routing:
  enabled: true
ingress:
 - hostname: geoserver.osm.lat
   service: http://localhost:8888
 - hostname: opendrone.osm.lat
   service: http://localhost:8000
 - hostname: terranote-wa.osm.lat
   service: http://localhost:8001
 - hostname: terranote-tg.osm.lat
   service: http://localhost:3000
 - hostname: terranote-tg-health.osm.lat
   service: http://localhost:3000
 - service: http_status:404
```

### 3. Reiniciar cloudflared

```bash
sudo systemctl restart cloudflared
```

### 4. Verificar

```bash
# Desde cualquier lugar
curl https://terranote-tg-health.osm.lat/health | jq
```

## Opción 2: Exponer `/metrics` con Autenticación (Recomendado para métricas detalladas)

### 1. Configurar autenticación en el adaptador

Editar `.env` del adaptador:

```bash
METRICS_USERNAME=admin
METRICS_PASSWORD=tu_contraseña_segura_aqui
```

**Generar contraseña segura:**
```bash
openssl rand -base64 32
```

### 2. Reiniciar el adaptador

```bash
sudo systemctl restart terranote-adapter-telegram
```

### 3. Configurar subdominio en Cloudflare DNS

1. Ir a Cloudflare Dashboard → DNS
2. Agregar registro CNAME:
   - **Nombre**: `terranote-tg-metrics.osm.lat`
   - **Target**: `1b718247-fe2d-4391-84c0-819c1501e6c2.cfargotunnel.com`
   - **Proxy**: Activado

### 4. Actualizar configuración de cloudflared

```yaml
ingress:
 - hostname: terranote-tg.osm.lat
   service: http://localhost:3000
 - hostname: terranote-tg-metrics.osm.lat
   service: http://localhost:3000
 - service: http_status:404
```

### 5. Reiniciar cloudflared

```bash
sudo systemctl restart cloudflared
```

### 6. Acceder a las métricas

```bash
# Con autenticación básica
curl -u admin:tu_contraseña_segura_aqui \
  https://terranote-tg-metrics.osm.lat/metrics

# O en el navegador (te pedirá usuario/contraseña)
# https://terranote-tg-metrics.osm.lat/metrics
```

## Opción 3: Exponer `/metrics` sin Autenticación (NO RECOMENDADO)

⚠️ **Solo para desarrollo/testing**. No usar en producción sin autenticación.

Si no configuras `METRICS_USERNAME` y `METRICS_PASSWORD`, el endpoint será público sin autenticación.

## Configuración Completa Recomendada

### Estructura de subdominios sugerida:

- `terranote-tg.osm.lat` → Webhook principal (ya configurado)
- `terranote-tg-health.osm.lat` → Health check público (sin autenticación, seguro)
- `terranote-tg-metrics.osm.lat` → Métricas (con autenticación básica)

### Configuración de cloudflared completa:

```yaml
tunnel: 1b718247-fe2d-4391-84c0-819c1501e6c2
credentials-file: /root/.cloudflared/1b718247-fe2d-4391-84c0-819c1501e6c2.json
warp-routing:
  enabled: true
ingress:
 - hostname: geoserver.osm.lat
   service: http://localhost:8888
 - hostname: opendrone.osm.lat
   service: http://localhost:8000
 - hostname: terranote-wa.osm.lat
   service: http://localhost:8001
 - hostname: terranote-tg.osm.lat
   service: http://localhost:3000
 - hostname: terranote-tg-health.osm.lat
   service: http://localhost:3000
 - hostname: terranote-tg-metrics.osm.lat
   service: http://localhost:3000
 - service: http_status:404
```

## Verificación

### Health check público:
```bash
curl https://terranote-tg-health.osm.lat/health
```

### Métricas con autenticación:
```bash
curl -u usuario:contraseña https://terranote-tg-metrics.osm.lat/metrics
```

### En Prometheus (si está configurado remotamente):

```yaml
scrape_configs:
  - job_name: 'terranote-adapter-telegram'
    scrape_interval: 15s
    basic_auth:
      username: 'admin'
      password: 'tu_contraseña'
    static_configs:
      - targets: ['terranote-tg-metrics.osm.lat']
        labels:
          service: 'telegram-adapter'
```

## Troubleshooting

### Error 530 en Cloudflare

- Verificar que el CNAME apunte a `*.cfargotunnel.com`
- Verificar que cloudflared esté corriendo: `sudo systemctl status cloudflared`
- Verificar logs: `sudo journalctl -u cloudflared -n 50`

### Error 401 Unauthorized

- Verificar que `METRICS_USERNAME` y `METRICS_PASSWORD` estén configurados
- Verificar que el adaptador se haya reiniciado después de cambiar `.env`
- Verificar logs: `sudo journalctl -u terranote-adapter-telegram -n 50`

### Métricas no aparecen

- Verificar que el adaptador esté corriendo: `curl http://localhost:3000/health`
- Verificar que haya tráfico (las métricas solo aparecen después de requests)
- Hacer algunas peticiones: `curl http://localhost:3000/health`

## Referencias

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Express Basic Auth](https://github.com/LionC/express-basic-auth)

