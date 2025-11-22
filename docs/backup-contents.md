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

### 3. Logs de Journald

**Ubicación en el backup:** `logs/journald/`

**Archivos generados:**
- `adapter.log` - Logs completos del adaptador
- `adapter_last_7days.log` - Logs de los últimos 7 días
- `core.log` - Logs completos del Core
- `core_last_7days.log` - Logs de los últimos 7 días

**Contiene:**
- Historial completo de operaciones
- Errores y warnings
- Información de debugging
- Trazas de requests y respuestas

**¿Por qué es importante?**
- Permite análisis post-mortem de incidentes
- Facilita debugging de problemas históricos
- Útil para auditorías y compliance

**Nota:** Los logs completos pueden ser muy grandes. El script respalda ambos (completos y últimos 7 días) para flexibilidad.

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
Backup típico:
- Configuración (.env): ~1-2 KB
- Systemd services: ~2-3 KB
- Logs (últimos 7 días): ~100 KB - 10 MB (depende del tráfico)
- Logs completos: Variable (puede ser grande)
- Infraestructura: ~50-100 KB
- Total comprimido: ~500 KB - 50 MB (típicamente 1-5 MB)
```

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
    ├── logs/
    │   └── journald/
    │       ├── adapter.log
    │       ├── adapter_last_7days.log
    │       ├── core.log
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

