# Script de Backup para Terranote

Script automatizado para hacer backup de configuración, logs y datos importantes de los servicios de Terranote.

## Uso

### Ejecución Manual

```bash
# Ejecutar backup
bash /home/terranote/terranote-infra/scripts/backup.sh

# O desde el directorio de infra
cd /home/terranote/terranote-infra
bash scripts/backup.sh
```

### Configuración

El script usa variables de entorno opcionales:

```bash
# Directorio base para backups (por defecto: /home/terranote/backups)
export BACKUP_BASE_DIR=/ruta/personalizada/backups

# Días de retención (por defecto: 7)
export RETENTION_DAYS=14

# Ejecutar con configuración personalizada
BACKUP_BASE_DIR=/backup/terranote RETENTION_DAYS=30 bash scripts/backup.sh
```

### Automatización con Cron

Para ejecutar backups automáticamente:

```bash
# Editar crontab
crontab -e

# Agregar línea para backup diario a las 2 AM
0 2 * * * /home/terranote/terranote-infra/scripts/backup.sh >> /var/log/terranote-backup.log 2>&1

# O backup cada 6 horas
0 */6 * * * /home/terranote/terranote-infra/scripts/backup.sh >> /var/log/terranote-backup.log 2>&1
```

### Automatización con systemd Timer (Recomendado)

Crear un timer de systemd es más robusto:

1. Crear archivo de servicio: `/etc/systemd/system/terranote-backup.service`

```ini
[Unit]
Description=Terranote Backup
After=network.target

[Service]
Type=oneshot
User=terranote
ExecStart=/home/terranote/terranote-infra/scripts/backup.sh
StandardOutput=journal
StandardError=journal
```

2. Crear archivo de timer: `/etc/systemd/system/terranote-backup.timer`

```ini
[Unit]
Description=Run Terranote Backup Daily
Requires=terranote-backup.service

[Timer]
OnCalendar=daily
OnCalendar=02:00
Persistent=true

[Install]
WantedBy=timers.target
```

3. Activar el timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable terranote-backup.timer
sudo systemctl start terranote-backup.timer

# Verificar
sudo systemctl status terranote-backup.timer
```

## Contenido del Backup

El script respalda:

1. **Archivos de configuración** (`.env`)
   - `terranote-adapter-telegram/.env`
   - `terranote-core/.env`

2. **Configuración de systemd**
   - `terranote-adapter-telegram.service`
   - `terranote-core.service`

3. **Logs de journald**
   - Logs completos del adaptador
   - Logs completos del core
   - Logs de los últimos 7 días (separados)

4. **Configuración de infraestructura**
   - Archivos de systemd del repo
   - Configuración de Prometheus (sin secrets)
   - Documentación

5. **Datos de Prometheus** (si está corriendo)
   - Configuración de Prometheus
   - Nota: Datos históricos no se respaldan por defecto (pueden ser grandes)

## Estructura del Backup

```
/home/terranote/backups/
├── terranote_20251121_020000.tar.gz
├── terranote_20251122_020000.tar.gz
└── ...
```

Al extraer un backup:

```
terranote_20251121_020000/
├── backup_info.txt          # Información del backup
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

## Restauración

### Restaurar Archivos de Configuración

```bash
# Extraer backup
cd /tmp
tar xzf /home/terranote/backups/terranote_20251121_020000.tar.gz

# Restaurar .env del adaptador
cp terranote_20251121_020000/config/adapter/.env /home/terranote/terranote-adapter-telegram/.env
chmod 600 /home/terranote/terranote-adapter-telegram/.env

# Restaurar .env del core
cp terranote_20251121_020000/config/core/.env /home/terranote/terranote-core/.env
chmod 600 /home/terranote/terranote-core/.env
```

### Restaurar Configuración de Systemd

```bash
# Restaurar archivos de servicio
sudo cp terranote_20251121_020000/systemd/*.service /etc/systemd/system/

# Recargar systemd
sudo systemctl daemon-reload

# Reiniciar servicios
sudo systemctl restart terranote-adapter-telegram terranote-core
```

### Restaurar Logs

Los logs se restauran manualmente si es necesario. Normalmente no es necesario restaurarlos, pero están disponibles en el backup para análisis.

## Retención

Por defecto, el script mantiene backups de los últimos 7 días. Backups más antiguos se eliminan automáticamente.

Para cambiar la retención:

```bash
RETENTION_DAYS=30 bash scripts/backup.sh
```

## Verificación

Para verificar que el backup se creó correctamente:

```bash
# Listar backups
ls -lh /home/terranote/backups/terranote_*.tar.gz

# Ver contenido de un backup
tar tzf /home/terranote/backups/terranote_20251121_020000.tar.gz | head -20

# Ver información del backup
tar xzf /home/terranote/backups/terranote_20251121_020000.tar.gz -O terranote_20251121_020000/backup_info.txt
```

## Troubleshooting

### Error de Permisos

Si encuentras errores de permisos:

```bash
# Asegurar que el directorio de backup existe y tiene permisos
mkdir -p /home/terranote/backups
chown terranote:terranote /home/terranote/backups
chmod 755 /home/terranote/backups
```

### Backup Muy Grande

Si el backup es muy grande, puedes excluir logs completos:

```bash
# Modificar el script para solo respaldar logs de últimos 7 días
# Comentar las líneas que exportan logs completos
```

### Espacio en Disco

Verificar espacio disponible:

```bash
# Ver espacio usado por backups
du -sh /home/terranote/backups

# Ver espacio disponible
df -h /home/terranote/backups
```

## Seguridad

⚠️ **Importante**: Los backups contienen información sensible (tokens, contraseñas).

- Almacenar backups en ubicación segura
- Usar permisos restrictivos: `chmod 600` en archivos `.env`
- Considerar encriptar backups si se almacenan fuera del servidor
- No compartir backups públicamente

## Referencias

- [Runbooks de Operaciones](../docs/runbooks.md)
- [Systemd Services](../systemd/README.md)

