# Configuración de Cloudflare Tunnel

Documentación de la configuración de Cloudflare Tunnel para exponer los servicios de Terranote públicamente.

## Configuración Actual

La configuración se encuentra en `/etc/cloudflared/config.yml`:

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
   service: http://localhost:3001
 - hostname: terranote-tg.osm.lat
   service: http://localhost:3000
 - hostname: terranote-tg-metrics.osm.lat
   service: http://localhost:3000
 - hostname: terranote-core-metrics.osm.lat
   service: http://localhost:3002
 - service: http_status:404
```

## Hostnames de Terranote

### Servicios Principales

| Hostname | Servicio | Puerto | Descripción |
|----------|----------|--------|-------------|
| `terranote-wa.osm.lat` | WhatsApp Adapter | 3001 | Adaptador de WhatsApp |
| `terranote-tg.osm.lat` | Telegram Adapter | 3000 | Adaptador de Telegram (webhook, health) |

### Endpoints de Métricas

| Hostname | Servicio | Puerto | Path | Autenticación |
|----------|----------|--------|------|---------------|
| `terranote-tg-metrics.osm.lat` | Telegram Adapter | 3000 | `/metrics` | Basic Auth (admin) |
| `terranote-core-metrics.osm.lat` | Core API | 3002 | `/metrics` | Sin autenticación |

## Verificación

### Verificar Configuración

```bash
# Ver configuración actual
sudo cat /etc/cloudflared/config.yml

# Ver estado del servicio
sudo systemctl status cloudflared

# Ver logs
sudo journalctl -u cloudflared -n 50
```

### Probar Endpoints

```bash
# Health check del adaptador (público)
curl https://terranote-tg.osm.lat/health | jq

# Métricas del adaptador (requiere autenticación)
curl -u admin:CONTRASEÑA https://terranote-tg-metrics.osm.lat/metrics | head -20

# Métricas del core (público)
curl https://terranote-core-metrics.osm.lat/metrics | head -20
```

## Corrección de Configuración

Si algún puerto está incorrecto:

```bash
# Ejecutar script de corrección
sudo bash /home/terranote/terranote-infra/scripts/fix-cloudflared-config.sh
```

O manualmente:

```bash
# Editar configuración
sudo nano /etc/cloudflared/config.yml

# Verificar puertos correctos:
#   - terranote-tg.osm.lat -> localhost:3000
#   - terranote-tg-metrics.osm.lat -> localhost:3000
#   - terranote-core-metrics.osm.lat -> localhost:3002
#   - terranote-wa.osm.lat -> localhost:3001

# Reiniciar servicio
sudo systemctl restart cloudflared
```

## Agregar Nuevos Hostnames

Para agregar un nuevo hostname:

1. Editar `/etc/cloudflared/config.yml`
2. Agregar entrada antes del catch-all (`- service: http_status:404`):

```yaml
 - hostname: nuevo-hostname.osm.lat
   service: http://localhost:PUERTO
```

3. Reiniciar cloudflared:

```bash
sudo systemctl restart cloudflared
```

4. Configurar DNS en Cloudflare:
   - Ir a Cloudflare Dashboard
   - Agregar registro CNAME: `nuevo-hostname` -> `1b718247-fe2d-4391-84c0-819c1501e6c2.cfargotunnel.com`

## Troubleshooting

### El servicio no responde

1. Verificar que el servicio local está corriendo:
   ```bash
   curl http://localhost:3000/health
   ```

2. Verificar que cloudflared está activo:
   ```bash
   sudo systemctl status cloudflared
   ```

3. Verificar logs de cloudflared:
   ```bash
   sudo journalctl -u cloudflared -f
   ```

### Error 404 en métricas

- Verificar que el path es correcto: `/metrics`
- Verificar que el servicio expone el endpoint `/metrics`
- Verificar autenticación si es requerida

### Puerto incorrecto

Si un hostname apunta a un puerto incorrecto:

1. Verificar puerto real del servicio:
   ```bash
   # Para adaptador de Telegram (puerto 3000)
   sudo systemctl status terranote-adapter-telegram | grep port
   
   # Para adaptador de WhatsApp (puerto 3001)
   # Verificar en el servicio correspondiente
   
   # Para core (puerto 3002)
   sudo systemctl status terranote-core | grep port
   
   # O verificar puertos en uso
   sudo ss -tlnp | grep -E ':(3000|3001|3002)'
   ```

2. Corregir en `/etc/cloudflared/config.yml`
3. Reiniciar cloudflared

## Seguridad

### Autenticación de Métricas

El endpoint de métricas del adaptador requiere autenticación básica:
- Usuario: `admin`
- Contraseña: Configurada en `.env` del adaptador

Para obtener la contraseña:

```bash
grep METRICS_PASSWORD /home/terranote/terranote-adapter-telegram/.env
```

### Recomendaciones

- Mantener métricas del core sin autenticación solo si es necesario
- Considerar agregar autenticación al core también
- Usar HTTPS (Cloudflare lo maneja automáticamente)
- Limitar acceso por IP si es posible

## Referencias

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Runbooks de Operaciones](./runbooks.md)
- [Acceso a Endpoints](../../terranote-adapter-telegram/docs/accessing-endpoints.md)

