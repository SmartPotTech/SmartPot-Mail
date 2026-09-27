# SmartPot-Mail (Mailpit)

## Estado del Proyecto

[![Mail Image CI](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/ci.yml)
[![Publish Docker Images](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml/badge.svg)](https://github.com/SmartPotTech/SmartPot-Mail/actions/workflows/packaging.yml)

## Descripción

SmartPot-Mail es el servidor de correo de SmartPot, basado en **Mailpit**. Recibe los correos que envía [SmartPot-API](https://github.com/SmartPotTech/SmartPot-API) —bienvenida y recuperación de contraseña— y los muestra en una interfaz web protegida. Si se configura un relay, además los reenvía a un SMTP real para que lleguen a los usuarios.

| Puerto | Uso | Producción |
| --- | --- | --- |
| 1025 | SMTP con autenticación | Solo la red interna de Docker |
| 8025 | Interfaz web y API de Mailpit, con usuario y contraseña | `https://mail.smartpot.app` a través de Nginx |

## Seguridad

- SMTP exige usuario y contraseña (`MAIL_USERNAME`, `MAIL_PASSWORD`); la autenticación sin TLS solo se permite porque el tráfico no sale de la red interna.
- La interfaz web exige su propio usuario y contraseña (`MAILPIT_UI_USERNAME`, `MAILPIT_UI_PASSWORD`). Antes era pública.
- Las credenciales se pasan a Mailpit por variables de entorno: no se escriben en archivos ni aparecen en los logs.
- Corre como el usuario `1000`, con sistema de archivos de solo lectura; los mensajes viven en `/tmp` y se descartan a los 30 días o al superar 500.

## Estructura del Proyecto

```text
SmartPot-Mail/
├── .github/
│   ├── dependabot.yml
│   └── workflows/
│       ├── ci.yml              # Construye la imagen y corre la prueba de seguridad
│       ├── packaging.yml       # Publica la imagen en GHCR (con SBOM y provenance)
│       └── deploy.yml          # Despliega la app completa tras publicar
├── tests/
│   └── smoke.sh                # Autenticación SMTP e interfaz, entrega y logs sin secretos
├── compose.yaml
├── Dockerfile                  # axllent/mailpit sin privilegios
├── entrypoint.sh               # Traduce las credenciales a la configuración de Mailpit
└── .env.example
```

## Guía de Instalación

```bash
git clone https://github.com/SmartPotTech/SmartPot-Mail.git
cd SmartPot-Mail
cp .env.example .env    # define las dos contraseñas
docker compose up -d
```

Abre `http://localhost:8025` con el usuario de la interfaz. La API se conecta con:

```text
MAIL_HOST=localhost  MAIL_PORT=1025  MAIL_USERNAME=smartpot  MAIL_PASSWORD=<MAIL_PASSWORD>  MAIL_SMTP_AUTH=true
```

### Entrega real (opcional)

Mailpit puede reenviar todos los mensajes a un proveedor SMTP. Descomenta las variables `MP_SMTP_RELAY_*` del `.env.example` con los datos del proveedor (por ejemplo, una contraseña de aplicación de Gmail) y deja `MP_SMTP_RELAY_ALL=true`.

### Prueba de humo

```bash
docker build -t smartpot-mail:ci .
sh tests/smoke.sh smartpot-mail:ci
```

## Imagen publicada

```bash
docker pull ghcr.io/smartpottech/smartpot-mail:latest
```

## Licencia

Este proyecto está bajo la licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
