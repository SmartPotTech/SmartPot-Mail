# SmartPot-Mail (Mailpit)

[![Mail Image CI](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml)

[English](#english) | [Español](#español)

---

## English

### Overview

SmartPot-Mail is the SmartPot mail server, powered by **Mailpit**. It receives the emails sent by [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) — welcome and password recovery — and displays them in a protected web UI. When an SMTP relay is configured, it also forwards them to a real SMTP provider so they reach users' inboxes.

| Port | Purpose                                              | Production                                    |
|------|------------------------------------------------------|-----------------------------------------------|
| 1025 | Authenticated SMTP                                   | Internal Docker network only                  |
| 8025 | Mailpit web UI and API, protected by username & pass | `https://mail.smartpot.app` behind Nginx      |

### Security

- SMTP requires a username and password (`MAIL_USERNAME`, `MAIL_PASSWORD`); plain authentication without TLS is only allowed because traffic never leaves the internal network.
- The web UI requires its own username and password (`MAILPIT_UI_USERNAME`, `MAILPIT_UI_PASSWORD`).
- Credentials are passed to Mailpit via environment variables: they are never written to files or printed in logs.
- Runs as user `1000` with a read-only filesystem; messages live in `/tmp` and expire after 30 days or once 500 messages are exceeded.

### Project Structure

```text
SmartPot-Mail/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Builds the image and runs the security smoke test
│       ├── packaging.yml       # Publishes the image to GHCR with SBOM and provenance (and Docker Hub when configured)
│       └── deploy.yml          # Triggers deployment on the central SmartPotTech/.github workflow
├── tests/
│   └── smoke.sh                # SMTP and UI authentication, delivery, and secret-free logs
├── compose.yaml
├── Dockerfile                  # Unprivileged axllent/mailpit
├── entrypoint.sh               # Translates credentials into Mailpit environment variables
└── .env.example
```

### Installation Guide

#### One-Command Deployment

The image is public: `ghcr.io/smartpottech/smartpot-mail`. The full platform, including this service, starts with a single command without cloning the code:

```bash
curl -fsSL https://raw.githubusercontent.com/SmartPotTech/.github/main/docker/demo/compose.yaml | docker compose -f - up -d --wait
```

Open http://localhost:5173 and sign in with `demo@smartpot.app` / `SmartPot2026`. Stop it with `docker compose -p smartpot-demo down` (add `-v` to also remove data). See the [demo](https://github.com/SmartPotTech/.github/tree/main/docker/demo) and [demo beta](https://github.com/SmartPotTech/.github/tree/main/docker/demo-beta) for details.

To run only this service from the published image:

```bash
docker run -d --name smartpot-mail --read-only --tmpfs /tmp --cap-drop ALL \
  -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 \
  -e MAIL_USERNAME=smartpot -e MAIL_PASSWORD=<smtp-password> \
  -e MAILPIT_UI_USERNAME=admin -e MAILPIT_UI_PASSWORD=<ui-password> \
  ghcr.io/smartpottech/smartpot-mail:latest
```

#### From Source with Docker Compose

```bash
cp .env.example .env    # set both passwords
docker compose up -d
```

Open `http://localhost:8025` with the UI credentials. The API connects with:

```text
MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_USERNAME=smartpot  MAIL_PASSWORD=<MAIL_PASSWORD>  MAIL_SMTP_AUTH=true
```

#### Real Delivery (Optional)

Mailpit can forward all messages to an upstream SMTP provider. Uncomment the `MP_SMTP_RELAY_*` variables in `.env.example` with the provider details (e.g., a Gmail app password) and set `MP_SMTP_RELAY_ALL=true`.

#### Smoke Test

```bash
docker build -t smartpot-mail:ci .
sh tests/smoke.sh smartpot-mail:ci
```

### Published Image

```bash
docker pull ghcr.io/smartpottech/smartpot-mail:latest
```

Every change on `main` runs through CI, publishes the image to GHCR (and Docker Hub as a replica when credentials are present), and triggers the central deployment workflow in [SmartPotTech/.github](https://github.com/SmartPotTech/.github), which updates production one service at a time and checks `/health`.

### Documentation

Email covers welcome and password recovery; crop alerts go through the PWA and Telegram. Component documentation is in [`docs/`](docs/SmartPot_Mail_Documentation.md) (also in [DOCX](docs/SmartPot_Mail_Documentation.docx) and [PDF](docs/SmartPot_Mail_Documentation.pdf)), with diagrams in [`docs/diagrams`](docs/diagrams).

- [Full Architecture](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_01_Architecture.svg): where Mailpit lives and how its inbox is exposed
- [Full Operation](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_02_Operation_Sequence.svg): registration welcome email and password recovery

### License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Español

### Descripción

SmartPot-Mail es el servidor de correo de SmartPot, basado en **Mailpit**. Recibe los correos que envía [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) —bienvenida y recuperación de contraseña— y los muestra en una interfaz web protegida. Si se configura un relay, además los reenvía a un SMTP real para que lleguen a los usuarios.

| Puerto | Uso                                                     | Producción                                    |
|--------|---------------------------------------------------------|-----------------------------------------------|
| 1025   | SMTP con autenticación                                  | Solo la red interna de Docker                 |
| 8025   | Interfaz web y API de Mailpit, con usuario y contraseña | `https://mail.smartpot.app` a través de Nginx |

### Seguridad

- SMTP exige usuario y contraseña (`MAIL_USERNAME`, `MAIL_PASSWORD`); la autenticación sin TLS solo se permite porque el tráfico no sale de la red interna.
- La interfaz web exige su propio usuario y contraseña (`MAILPIT_UI_USERNAME`, `MAILPIT_UI_PASSWORD`). Antes era pública.
- Las credenciales se pasan a Mailpit por variables de entorno: no se escriben en archivos ni aparecen en los logs.
- Corre como el usuario `1000`, con sistema de archivos de solo lectura; los mensajes viven en `/tmp` y se descartan a los 30 días o al superar 500.

### Estructura del Proyecto

```text
SmartPot-Mail/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Construye la imagen y corre la prueba de seguridad
│       ├── packaging.yml       # Publica la imagen en GHCR con SBOM y procedencia (y en Docker Hub con credenciales)
│       └── deploy.yml          # Pide el despliegue al workflow central de SmartPotTech/.github
├── tests/
│   └── smoke.sh                # Autenticación SMTP e interfaz, entrega y logs sin secretos
├── compose.yaml
├── Dockerfile                  # axllent/mailpit sin privilegios
├── entrypoint.sh               # Traduce las credenciales a la configuración de Mailpit
└── .env.example
```

### Guía de Instalación

#### Despliegue en un comando

La imagen es pública: `ghcr.io/smartpottech/smartpot-mail`. La plataforma completa, con este servicio incluido, se levanta con un solo comando y sin descargar el código:

```bash
curl -fsSL https://raw.githubusercontent.com/SmartPotTech/.github/main/docker/demo/compose.yaml | docker compose -f - up -d --wait
```

Abre http://localhost:5173 e ingresa con `demo@smartpot.app` / `SmartPot2026`. Se detiene con `docker compose -p smartpot-demo down` (con `-v` borra también los datos). Más detalle en la [demo](https://github.com/SmartPotTech/.github/tree/main/docker/demo) y en la [demo beta](https://github.com/SmartPotTech/.github/tree/main/docker/demo-beta).

Solo este servicio, con la imagen publicada:

```bash
docker run -d --name smartpot-mail --read-only --tmpfs /tmp --cap-drop ALL \
  -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 \
  -e MAIL_USERNAME=smartpot -e MAIL_PASSWORD=<contraseña-smtp> \
  -e MAILPIT_UI_USERNAME=admin -e MAILPIT_UI_PASSWORD=<contraseña-de-la-interfaz> \
  ghcr.io/smartpottech/smartpot-mail:latest
```

#### Desde el código con Docker Compose

```bash
cp .env.example .env    # define las dos contraseñas
docker compose up -d
```

Abre `http://localhost:8025` con el usuario de la interfaz. La API se conecta con:

```text
MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_USERNAME=smartpot  MAIL_PASSWORD=<MAIL_PASSWORD>  MAIL_SMTP_AUTH=true
```

#### Entrega real (opcional)

Mailpit puede reenviar todos los mensajes a un proveedor SMTP. Descomenta las variables `MP_SMTP_RELAY_*` del `.env.example` con los datos del proveedor (por ejemplo, una contraseña de aplicación de Gmail) y deja `MP_SMTP_RELAY_ALL=true`.

#### Prueba de humo

```bash
docker build -t smartpot-mail:ci .
sh tests/smoke.sh smartpot-mail:ci
```

### Imagen publicada

```bash
docker pull ghcr.io/smartpottech/smartpot-mail:latest
```

Cada cambio en `main` pasa por el CI, publica la imagen en GHCR (y en Docker Hub como réplica cuando el repositorio tiene credenciales) y pide el despliegue al workflow central de [SmartPotTech/.github](https://github.com/SmartPotTech/.github), que actualiza producción de a uno y verifica `/health`.

### Documentación

El correo cubre la bienvenida y la recuperación de la contraseña; los avisos del cultivo van por la PWA y Telegram. Su documentación propia está en [`docs/`](docs/SmartPot_Mail_Documentation.md) (también en [DOCX](docs/SmartPot_Mail_Documentation.docx) y [PDF](docs/SmartPot_Mail_Documentation.pdf)), con sus diagramas en [`docs/diagrams`](docs/diagrams).

- [Arquitectura completa](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_01_Architecture.svg): dónde vive Mailpit y cómo se publica su bandeja
- [Operación completa](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_02_Operation_Sequence.svg): el registro con su correo de bienvenida y la recuperación de la contraseña

### Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
