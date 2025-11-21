# Terranote Infra

Infraestructura compartida para el ecosistema Terranote. Este repositorio reúne los archivos `docker-compose`, plantillas de variables y guías necesarias para orquestar el módulo central (`terranote-core`), los adaptadores de mensajería (WhatsApp, Telegram, etc.), fakes de servicios externos y herramientas de observabilidad en entornos de desarrollo y pruebas.

## Requisitos previos

- Clonar los repositorios de aplicación y herramientas dentro del mismo directorio base:
  - [`terranote-core`](https://github.com/Terranote/terranote-core)
  - [`terranote-adapter-whatsapp`](https://github.com/Terranote/terranote-adapter-whatsapp)
  - [`terranote-tests`](https://github.com/Terranote/terranote-tests)
  - (Opcional) Otros adaptadores según se vayan añadiendo.
- Docker y Docker Compose v2.
- Acceso a los tokens necesarios de WhatsApp Cloud API para pruebas reales.

La estructura recomendada es:

```
~/proyectos/
├── terranote-core/
├── terranote-adapter-whatsapp/
├── terranote-tests/
└── terranote-infra/
```

## Escenarios disponibles

### WhatsApp E2E (fase 1)

Ubicación: `compose/whatsapp-e2e/docker-compose.yml`

Servicios incluidos:

| Servicio          | Puerto | Descripción                                        |
| ----------------- | ------ | -------------------------------------------------- |
| `terranote-core`  | 8000   | API central (`POST /api/v1/interactions`, etc.).   |
| `adapter`         | 8001   | Adaptador de WhatsApp (webhook y callbacks).       |
| `fake-osm`        | 8080   | API de OSM simulada para pruebas controladas.      |

### Puesta en marcha

1. Copia el archivo `compose/whatsapp-e2e/env.whatsapp.example` a `compose/whatsapp-e2e/env.whatsapp` y completa los valores reales (tokens de Meta, verify token, etc.).
2. Desde este repositorio ejecuta:

   ```bash
   docker compose -f compose/whatsapp-e2e/docker-compose.yml --env-file compose/whatsapp-e2e/env.whatsapp up --build
   ```

   - `terranote-core` quedará expuesto en `http://localhost:8000`.
   - El adaptador escuchará en `http://localhost:8001`.
   - `fake-osm` estará disponible en `http://localhost:8080`.

3. Abre un túnel (`ngrok http 8001` o `cloudflared tunnel run`) y registra la URL pública en la consola de WhatsApp Cloud API, utilizando el verify token configurado.
4. Sigue las guías de los repositorios de aplicación para enviar mensajes de prueba y confirmar la creación de notas.

## Documentación relacionada

- Guía end-to-end del núcleo: [`terranote-core/docs/e2e-guide.md`](https://github.com/Terranote/terranote-core/blob/main/docs/e2e-guide.md)
- Estrategia documental global: [`terranote-docs`](https://github.com/Terranote/terranote-docs)
- Detalles de escenarios de prueba: [`terranote-tests`](https://github.com/Terranote/terranote-tests)

## Systemd Services

Ubicación: `systemd/`

Archivos de servicio systemd para gestionar los servicios de Terranote en producción:

- `terranote-adapter-telegram.service` - Adaptador de Telegram
- `terranote-core.service` - API central

Ver [`systemd/README.md`](systemd/README.md) para instrucciones de instalación y gestión.

### Logging con journald

Todos los servicios están configurados para usar journald de systemd. Los logs se capturan automáticamente y se pueden consultar con:

```bash
# Ver logs en tiempo real
sudo journalctl -u terranote-adapter-telegram -f
sudo journalctl -u terranote-core -f
```

## Prometheus & Grafana Monitoring

Ubicación: `prometheus/`

Configuración de Prometheus y Grafana para monitorear los servicios de Terranote:

- `terranote-adapter-telegram` - Métricas del adaptador de Telegram
- `terranote-core` - Métricas del Core API

Ver [`prometheus/README.md`](prometheus/README.md) para instrucciones de configuración y uso.

### Inicio Rápido

```bash
cd prometheus
docker compose up -d
```

- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3001` (usuario: `admin`, contraseña: `admin`)

El dashboard "Terranote Overview" se carga automáticamente en Grafana.

## Próximos pasos

- Añadir escenarios adicionales (Telegram, plugins multimedia, observabilidad).
- Publicar imágenes Docker oficiales para evitar builds locales.
- Integrar scripts/plantillas de despliegue hacia entornos staging/producción.

## Licencia

GPL-3.0-or-later. Consulte el archivo `LICENSE` para más detalles.
