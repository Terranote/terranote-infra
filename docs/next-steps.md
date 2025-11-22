# Próximos Pasos - Mejoras y Expansión

Este documento describe las mejoras opcionales y próximos pasos para el ecosistema Terranote.

## 1. Monitoreo

### Estado Actual

**Terranote Core:**
- ✅ `/api/v1/status` - Health check con métricas
- ✅ `/metrics` - Endpoint Prometheus
- ✅ Métricas: `note_publication_attempts`, `note_publication_successes`, etc.

**Telegram Adapter:**
- ✅ `/health` - Health check con información detallada (uptime, version, dependencias)
- ✅ `/metrics` - Endpoint Prometheus
- ✅ Métricas: HTTP requests, Core API calls, Telegram API calls, message processing

### Opciones de Monitoreo

#### Opción A: Health Checks Simples (Mínimo)

**Implementación:**
- Script de cron que verifica endpoints cada 5 minutos
- Alertas por email cuando falla

**Pros:**
- Fácil de implementar
- Bajo overhead
- Bueno para despliegues pequeños

**Cons:**
- Visibilidad limitada
- Sin datos históricos
- Configuración manual de alertas

**Ejemplo:**
```bash
# /etc/cron.d/terranote-health
*/5 * * * * root curl -f https://terranote-tg.osm.lat/health || echo "Adapter down" | mail -s "Alert" admin@example.com
```

#### Opción B: Prometheus + Grafana (Recomendado) ⭐

**Arquitectura:**
```
Telegram Adapter → /metrics → Prometheus → Grafana
Terranote Core   → /metrics → Prometheus → Grafana
```

**Implementación:**
1. Agregar endpoint `/metrics` al adaptador de Telegram
2. Configurar Prometheus para scrapear ambos servicios
3. Crear dashboards en Grafana
4. Configurar Alertmanager para alertas

**Métricas a rastrear:**
- Request rate (requests/segundo)
- Error rate (4xx, 5xx)
- Response time (p50, p95, p99)
- Conexiones activas
- Tiempo de procesamiento de mensajes
- Latencia de llamadas al Core API
- Latencia de llamadas a Telegram API

**Ventajas:**
- Métricas y dashboards ricos
- Datos históricos
- Alertas con Alertmanager
- Estándar de la industria

**Desventajas:**
- Requiere infraestructura adicional
- Setup más complejo

**Archivos a crear en `terranote-infra`:**
- `monitoring/prometheus.yml` - Configuración de Prometheus
- `monitoring/grafana/dashboards/` - Dashboards de Grafana
- `monitoring/alertmanager.yml` - Reglas de alertas
- `compose/monitoring/docker-compose.yml` - Stack de monitoreo

#### Opción C: Monitoreo Externo de Uptime

**Servicios:**
- UptimeRobot (tier gratuito: 50 monitores)
- Pingdom
- StatusCake
- Better Uptime

**Ventajas:**
- No requiere infraestructura propia
- Perspectiva externa
- Alertas por email/SMS

**Desventajas:**
- Limitado a checks HTTP
- Sin métricas detalladas
- Dependencia externa

### Recomendación

**Fase 1 (Inmediato):** Mejorar endpoint `/health` del adaptador
```json
{
  "status": "ok",
  "uptime": 3600,
  "version": "0.1.0",
  "dependencies": {
    "core": "ok",
    "telegram": "ok"
  }
}
```

**Fase 2 (Corto plazo):** Agregar endpoint `/metrics` al adaptador
- Usar `prom-client` (similar a core)
- Exponer métricas HTTP estándar

**Fase 3 (Mediano plazo):** Stack completo Prometheus + Grafana
- Configurar en `terranote-infra`
- Dashboards pre-configurados
- Alertas básicas

## 2. Pruebas End-to-End (E2E)

### Estado Actual

**Repositorio:** `terranote-tests`
- ✅ Escenarios para WhatsApp
- ✅ Scripts de prueba automatizados
- ✅ Reportes en Markdown
- ✅ Escenarios para Telegram
- ✅ Scripts de prueba E2E para Telegram (texto+ubicación, solo texto, solo ubicación)

### Extensión para Telegram

**Estructura propuesta:**
```
terranote-tests/
├── scenarios/
│   ├── whatsapp/          # ✅ Ya existe
│   │   ├── cases/
│   │   │   ├── test_text_location.py
│   │   │   ├── test_missing_text.py
│   │   │   └── test_missing_location.py
│   │   └── env/
│   └── telegram/          # ⭐ Nuevo
│       ├── cases/
│       │   ├── test_text_location.py
│       │   ├── test_location_only.py
│       │   └── test_text_only.py
│       └── env/
│           └── env.sample
```

**Casos de prueba para Telegram:**
1. **Texto + Ubicación** → Creación de nota → Callback exitoso
2. **Solo texto** → Espera ubicación → Mensaje al usuario
3. **Solo ubicación** → Espera texto → Mensaje al usuario
4. **Sesión expirada** → Mensaje de error al usuario
5. **Mensaje no soportado** → Ignorado correctamente

**Implementación:**
- Adaptar scripts de WhatsApp para Telegram
- Usar formato de webhook de Telegram
- Verificar callbacks del core
- Validar mensajes de confirmación

**Ejemplo de script:**
```python
# scenarios/telegram/cases/test_text_location.py
def test_text_and_location():
    # 1. Enviar mensaje de texto
    text_update = {
        "update_id": 1,
        "message": {
            "message_id": 1,
            "from": {"id": "12345"},
            "chat": {"id": "12345"},
            "text": "Hay una vía cerrada"
        }
    }
    
    # 2. Enviar ubicación
    location_update = {
        "update_id": 2,
        "message": {
            "message_id": 2,
            "from": {"id": "12345"},
            "chat": {"id": "12345"},
            "location": {
                "latitude": 4.711,
                "longitude": -74.072
            }
        }
    }
    
    # 3. Verificar creación de nota
    # 4. Verificar callback al usuario
```

## 3. Documentación de Operaciones

### Runbooks

Documentar procedimientos comunes:

**Archivos a crear:**
- `docs/runbooks/service-restart.md` - Cómo reiniciar servicios
- `docs/runbooks/troubleshooting.md` - Solución de problemas comunes
- `docs/runbooks/deployment.md` - Proceso de despliegue
- `docs/runbooks/backup-restore.md` - Backup y restauración

**Ejemplo de runbook:**
```markdown
# Runbook: Reiniciar Adaptador de Telegram

## Síntomas
- El adaptador no responde
- Errores 502 en webhook
- Logs muestran errores de conexión

## Pasos
1. Verificar estado: `sudo systemctl status terranote-adapter-telegram`
2. Ver logs: `sudo journalctl -u terranote-adapter-telegram -n 50`
3. Reiniciar: `sudo systemctl restart terranote-adapter-telegram`
4. Verificar: `curl https://terranote-tg.osm.lat/health`
```

### Documentación de Incidentes

**Template:**
```markdown
# Incidente: [Fecha] - [Descripción breve]

## Resumen
- **Fecha/Hora:** 
- **Duración:** 
- **Impacto:** 
- **Causa raíz:** 

## Timeline
- HH:MM - Detectado
- HH:MM - Investigación iniciada
- HH:MM - Solución aplicada
- HH:MM - Resuelto

## Acciones tomadas
1. 
2. 

## Lecciones aprendidas
- 
- 

## Acciones de seguimiento
- [ ] 
- [ ]
```

## 4. Backup y Restauración

### Estrategia de Backup

**Datos a respaldar:**
1. **Configuración**
   - Archivos `.env` (sin tokens en Git)
   - Archivos de servicio systemd
   - Configuración de cloudflared

2. **Código**
   - Repositorios Git (ya están en GitHub)
   - Tags de versiones

3. **Infraestructura**
   - Configuración de DNS (Cloudflare)
   - Configuración de túneles (cloudflared)

### Implementación

**Script de backup:**
```bash
#!/bin/bash
# terranote-infra/scripts/backup.sh

BACKUP_DIR="/backup/terranote/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup de configuración
tar -czf "$BACKUP_DIR/config.tar.gz" \
  /home/terranote/terranote-*/.env \
  /etc/systemd/system/terranote-*.service \
  /etc/cloudflared/config.yml

# Backup de logs (últimos 7 días)
journalctl -u terranote-* --since "7 days ago" > "$BACKUP_DIR/logs.txt"

# Backup de métricas (si existe Prometheus)
# promtool tsdb dump > "$BACKUP_DIR/metrics.dump"
```

**Cron job:**
```bash
# Backup diario a las 2 AM
0 2 * * * /path/to/backup.sh
```

**Retención:**
- Diarios: últimos 7 días
- Semanales: últimas 4 semanas
- Mensuales: últimos 3 meses

### Restauración

**Procedimiento:**
1. Restaurar archivos `.env`
2. Restaurar servicios systemd
3. Reiniciar servicios
4. Verificar salud de servicios

## Priorización

### Completado ✅
1. ✅ Mejorar endpoint `/health` del adaptador
2. ✅ Agregar endpoint `/metrics` al adaptador
3. ✅ Crear escenarios E2E para Telegram
4. ✅ Configurar Prometheus + Grafana
5. ✅ Documentar runbooks básicos
6. ✅ Script de backup automatizado
7. ✅ Exponer métricas públicamente con Cloudflare Tunnel

### Próximos Pasos (Alta Prioridad)
1. ⭐ Script de monitoreo automatizado con alertas
2. ⭐ Configurar Alertmanager con reglas básicas
3. ⭐ Automatizar backups con systemd timer

### Próximos Pasos (Media Prioridad)
4. ⭐ Dashboards más detallados en Grafana
5. ⭐ Integración con CI/CD para despliegues automáticos
6. ⭐ Documentación de incidentes y post-mortems

### Próximos Pasos (Baja Prioridad)
7. ⭐ Alertmanager con reglas avanzadas
8. ⭐ Métricas de negocio (notas creadas por día, usuarios activos, etc.)
9. ⭐ Integración con servicios externos de monitoreo (UptimeRobot, etc.)

## Referencias

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Client for Node.js](https://github.com/siimon/prom-client)
- [Runbook Template](https://github.com/SREBook/sre-book)

