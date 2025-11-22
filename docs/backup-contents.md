# Contenido de los Backups

Este documento explica qué se respalda en los backups automatizados de Terranote.

## ¿Qué se Respalda?

El script de backup (`scripts/backup.sh`) respalda los siguientes elementos:

### 1. Archivos de Configuración (`.env`)

**Ubicación en el backup:** `config/adapter/.env` y `config/core/.env`

**Contiene:**
- Tokens y credenciales (Telegram Bot Token, Core API Token, etc.)
- URLs de servicios
- Configuraciones de timeouts
- Variables de entorno específicas del servicio

**¿Por qué es importante?**
- Sin estos archivos, los servicios no pueden iniciar
- Contienen información sensible que no está en Git
- Son únicos por entorno (desarrollo, producción)

**Ejemplo de contenido:**
```bash
TELEGRAM_BOT_TOKEN=123456:ABC-DEF...
CORE_API_BASE_URL=http://localhost:3002
CORE_API_TOKEN=secret-token-here
METRICS_USERNAME=admin
METRICS_PASSWORD=secure-password
```

### 2. Configuración de Systemd

**Ubicación en el backup:** `systemd/*.service`

**Archivos respaldados:**
- `/etc/systemd/system/terranote-adapter-telegram.service`
- `/etc/systemd/system/terranote-core.service`

**Contiene:**
- Configuración de cómo se ejecutan los servicios
- Variables de entorno
- Rutas de trabajo
- Configuración de seguridad
- Configuración de reinicio automático

**¿Por qué es importante?**
- Permite restaurar la configuración exacta de los servicios
- Incluye ajustes de seguridad y permisos
- Facilita la replicación en otros servidores

### 3. Logs de Journald (Opcional)

**Ubicación en el backup:** `logs/journald/` (solo si `BACKUP_LOGS=true`)

**Por defecto:** Los logs NO se respaldan

**Razón:** Los logs pueden ser muy grandes (varios MB o GB) y journald ya los mantiene de forma persistente. Los logs están disponibles en journald con:
```bash
sudo journalctl -u terranote-adapter-telegram
sudo journalctl -u terranote-core
```

**Si se habilita** (`BACKUP_LOGS=true`):
- Solo respalda logs de los últimos 7 días (más manejable)
- `adapter_last_7days.log` - Logs del adaptador (últimos 7 días)
- `core_last_7days.log` - Logs del Core (últimos 7 días)

**¿Cuándo habilitar logs en backup?**
- Si necesitas exportar logs para análisis externo
- Si vas a migrar a otro servidor y quieres llevar logs
- Si journald no está configurado para persistencia

**Recomendación:** Mantener `BACKUP_LOGS=false` por defecto. Los logs están en journald y pueden consultarse cuando se necesiten.

### 4. Configuración de Infraestructura

**Ubicación en el backup:** `infra/`

**Incluye:**
- `systemd/` - Archivos de servicio del repositorio
- `prometheus/` - Configuración de Prometheus (sin secrets)
- `docs/` - Documentación

**Contiene:**
- Configuración de monitoreo
- Scripts de instalación
- Documentación operativa

**¿Por qué es importante?**
- Permite restaurar la configuración de monitoreo
- Facilita la replicación de la infraestructura
- Documenta el estado de la configuración

### 5. Datos de Prometheus (Opcional)

**Ubicación en el backup:** `prometheus-data/`

**Incluye:**
- `prometheus.yml` - Configuración de Prometheus

**Nota:** Los datos históricos de métricas NO se respaldan por defecto porque pueden ser muy grandes (varios GB). Si necesitas respaldar datos históricos, puedes hacerlo manualmente.

**¿Por qué es importante?**
- Permite restaurar la configuración de Prometheus
- Los datos históricos pueden regenerarse (aunque se pierde el historial)

## ¿Qué NO se Respalda?

### Código Fuente
- Los repositorios Git ya están en GitHub
- No es necesario respaldar código local

### Base de Datos
- Terranote no usa base de datos propia
- Los datos están en OSM (servicio externo)

### Datos de Métricas Históricas
- Por defecto no se respaldan (muy grandes)
- Pueden regenerarse con el tiempo

### Archivos Temporales
- Cache de Node.js/Python
- Archivos de build
- node_modules, __pycache__, etc.

## Tamaño Típico de un Backup

```
Backup típico (sin logs):
- Configuración (.env): ~1-2 KB
- Systemd services: ~2-3 KB
- Infraestructura: ~50-100 KB
- Total comprimido: ~100-200 KB

Backup con logs (BACKUP_LOGS=true):
- Configuración (.env): ~1-2 KB
- Systemd services: ~2-3 KB
- Logs (últimos 7 días): ~100 KB - 10 MB (depende del tráfico)
- Infraestructura: ~50-100 KB
- Total comprimido: ~500 KB - 50 MB (típicamente 1-5 MB)
```

**Recomendación:** Mantener logs fuera del backup por defecto. Los backups serán más pequeños y rápidos.

## Frecuencia de Backup Recomendada

- **Diario**: Para configuración y logs recientes
- **Semanal**: Para logs completos (si es necesario)
- **Antes de cambios importantes**: Manual antes de actualizaciones

## Retención

Por defecto, el script mantiene backups de los últimos **7 días**. Esto puede ajustarse con la variable `RETENTION_DAYS`.

## Restauración

Ver [`scripts/README-backup.md`](../scripts/README-backup.md) para instrucciones detalladas de restauración.

## Ejemplo de Estructura de Backup

```
terranote_20251122_020000.tar.gz
└── terranote_20251122_020000/
    ├── backup_info.txt
    ├── config/
    │   ├── adapter/
    │   │   └── .env
    │   └── core/
    │       └── .env
    ├── systemd/
    │   ├── terranote-adapter-telegram.service
    │   └── terranote-core.service
    ├── logs/ (solo si BACKUP_LOGS=true)
    │   └── journald/
    │       ├── adapter_last_7days.log
    │       └── core_last_7days.log
    ├── infra/
    │   ├── systemd/
    │   ├── prometheus/
    │   └── docs/
    └── prometheus-data/ (si aplica)
```

## Seguridad

⚠️ **Importante**: Los backups contienen información sensible:
- Tokens de API
- Contraseñas
- Credenciales

**Recomendaciones:**
- Almacenar backups en ubicación segura
- Usar permisos restrictivos (`chmod 600`)
- Considerar encriptación si se almacenan fuera del servidor
- No compartir backups públicamente
- Rotar credenciales periódicamente

