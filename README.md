# Terranote Infra

Infraestructura compartida para el ecosistema Terranote. Este repositorio reúne los archivos `docker-compose`, plantillas de variables y guías necesarias para orquestar el módulo central (`terranote-core`), los adaptadores de mensajería (WhatsApp, Telegram, etc.), fakes de servicios externos y herramientas de observabilidad en entornos de desarrollo y pruebas.

## Requisitos previos

- Clonar los repositorios de aplicación dentro del mismo directorio base:
  - [`terranote-core`](https://github.com/Terranote/terranote-core)
  - [`terranote-adapter-whatsapp`](https://github.com/Terranote/terranote-adapter-whatsapp)
  - (Opcional) Otros adaptadores según se vayan añadiendo.
- Docker y Docker Compose v2.
- Acceso a los tokens necesarios de WhatsApp Cloud API para pruebas reales.

La estructura recomendada es:

```
~/proyectos/
├── terranote-core/
├── terranote-adapter-whatsapp/
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

## Próximos pasos

- Añadir escenarios adicionales (Telegram, plugins multimedia, observabilidad).
- Publicar imágenes Docker oficiales para evitar builds locales.
- Integrar scripts/plantillas de despliegue hacia entornos staging/producción.

## Licencia

GPL-3.0-or-later. Consulte el archivo `LICENSE` para más detalles.

# terranote-infra
Infraestructura compartida de Terranote. Contiene los entornos docker-compose, scripts de despliegue y herramientas auxiliares para orquestar terranote-core, los adaptadores (WhatsApp, Telegram, etc.), fakes de OSM y servicios de observabilidad en escenarios de desarrollo, pruebas y producción.
