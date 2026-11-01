# SmartPot-Mail (Mailpit)

## Estado del Proyecto

[![Mail Image CI](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml)

## Descripción

SmartPot-Mail es el servidor de correo de SmartPot, basado en **Mailpit**. Recibe los correos que
envía [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) —bienvenida y recuperación de contraseña— y los
muestra en una interfaz web protegida. Si se configura un relay, además los reenvía a un SMTP real para que lleguen a
los usuarios.

| Puerto | Uso                                                     | Producción                                    |
|--------|---------------------------------------------------------|-----------------------------------------------|
| 1025   | SMTP con autenticación                                  | Solo la red interna de Docker                 |
| 8025   | Interfaz web y API de Mailpit, con usuario y contraseña | `https://mail.smartpot.app` a través de Nginx |

## Seguridad

- SMTP exige usuario y contraseña (`MAIL_USERNAME`, `MAIL_PASSWORD`); la autenticación sin TLS solo se permite porque el
  tráfico no sale de la red interna.
- La interfaz web exige su propio usuario y contraseña (`MAILPIT_UI_USERNAME`, `MAILPIT_UI_PASSWORD`). Antes era
  pública.
- Las credenciales se pasan a Mailpit por variables de entorno: no se escriben en archivos ni aparecen en los logs.
- Corre como el usuario `1000`, con sistema de archivos de solo lectura; los mensajes viven en `/tmp` y se descartan a
  los 30 días o al superar 500.

## Estructura del Proyecto

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

## Guía de Instalación

### Despliegue en un comando

La imagen es pública: `ghcr.io/smartpottech/smartpot-mail`. La plataforma completa, con este servicio incluido, se
levanta con un solo comando y sin descargar el código:

```bash
curl -fsSL https://raw.githubusercontent.com/SmartPotTech/.github/main/docker/demo/compose.yaml | docker compose -f - up -d --wait
```

Abre http://localhost:5173 e ingresa con `demo@smartpot.app` / `SmartPot2026`. Se detiene con
`docker compose -p smartpot-demo down` (con `-v` borra también los datos). Más detalle en la
[demo](https://github.com/SmartPotTech/.github/tree/main/docker/demo).
El mismo servicio corre en la [demo beta](https://github.com/SmartPotTech/.github/tree/main/docker/demo-beta) del stack nuevo: cambia `demo` por `demo-beta`
en la URL y en el nombre del proyecto.

Solo este servicio, con la imagen publicada:

```bash
docker run -d --name smartpot-mail --read-only --tmpfs /tmp --cap-drop ALL \
  -p 127.0.0.1:1025:1025 -p 127.0.0.1:8025:8025 \
  -e MAIL_USERNAME=smartpot -e MAIL_PASSWORD=<contraseña-smtp> \
  -e MAILPIT_UI_USERNAME=admin -e MAILPIT_UI_PASSWORD=<contraseña-de-la-interfaz> \
  ghcr.io/smartpottech/smartpot-mail:latest
```

### Desde el código con Docker Compose

```bash
cp .env.example .env    # define las dos contraseñas
docker compose up -d
```

Abre `http://localhost:8025` con el usuario de la interfaz. La API se conecta con:

```text
MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_USERNAME=smartpot  MAIL_PASSWORD=<MAIL_PASSWORD>  MAIL_SMTP_AUTH=true
```

### Entrega real (opcional)

Mailpit puede reenviar todos los mensajes a un proveedor SMTP. Descomenta las variables `MP_SMTP_RELAY_*` del
`.env.example` con los datos del proveedor (por ejemplo, una contraseña de aplicación de Gmail) y deja
`MP_SMTP_RELAY_ALL=true`.

### Prueba de humo

```bash
docker build -t smartpot-mail:ci .
sh tests/smoke.sh smartpot-mail:ci
```

## Imagen publicada

```bash
docker pull ghcr.io/smartpottech/smartpot-mail:latest
```

Cada cambio en `main` pasa por el CI, publica la imagen en GHCR (y en Docker Hub como réplica cuando el repositorio
tiene credenciales) y pide el despliegue al workflow central
de [SmartPotTech/.github](https://github.com/SmartPotTech/.github), que actualiza producción de a uno y verifica
`/health`.

## Documentación

El correo cubre la bienvenida y la recuperación de la contraseña; los avisos del cultivo van por la PWA y Telegram. Su
documentación propia está en [`docs/`](docs/SmartPot_Mail_Documentation.md) (también
en [DOCX](docs/SmartPot_Mail_Documentation.docx) y [PDF](docs/SmartPot_Mail_Documentation.pdf)), con sus diagramas en [
`docs/diagrams`](docs/diagrams): el general de la imagen y el flujo de los correos.
La [documentación técnica](https://github.com/SmartPotTech/.github/blob/main/docs/SmartPot_Technical_Documentation.md)
describe la red de producción y cómo se protege la bandeja. Los diagramas generales muestran la plataforma completa en
una sola imagen ampliable:

- [Arquitectura completa](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_01_Architecture.svg):
  dónde vive Mailpit y cómo se publica su bandeja
- [Operación completa](https://github.com/SmartPotTech/.github/blob/main/docs/diagrams/SmartPot_Global_02_Operation_Sequence.svg):
  el registro con su correo de bienvenida y la recuperación de la contraseña

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
