#!/bin/sh
set -eu

: "${MAIL_USERNAME:?Falta MAIL_USERNAME para la autenticación SMTP}"
: "${MAIL_PASSWORD:?Falta MAIL_PASSWORD para la autenticación SMTP}"
: "${MAILPIT_UI_USERNAME:?Falta MAILPIT_UI_USERNAME para proteger la interfaz web}"
: "${MAILPIT_UI_PASSWORD:?Falta MAILPIT_UI_PASSWORD para proteger la interfaz web}"

for secret in "$MAIL_PASSWORD" "$MAILPIT_UI_PASSWORD"; do
  if [ "${#secret}" -lt 12 ]; then
    echo "Las contraseñas de Mailpit deben tener al menos 12 caracteres."
    exit 1
  fi
done

# Mailpit lee las credenciales del entorno; así no quedan en archivos ni en los logs.
export MP_SMTP_AUTH="$MAIL_USERNAME:$MAIL_PASSWORD"
export MP_UI_AUTH="$MAILPIT_UI_USERNAME:$MAILPIT_UI_PASSWORD"
export MP_SMTP_AUTH_ALLOW_INSECURE="${MP_SMTP_AUTH_ALLOW_INSECURE:-true}"
export MP_MAX_MESSAGES="${MP_MAX_MESSAGES:-500}"
export MP_MAX_AGE="${MP_MAX_AGE:-30d}"
unset MAIL_PASSWORD MAILPIT_UI_PASSWORD

echo "Mailpit con autenticación SMTP (usuario $MAIL_USERNAME) e interfaz protegida (usuario $MAILPIT_UI_USERNAME)."
exec /mailpit --smtp "0.0.0.0:1025" --listen "0.0.0.0:8025" "$@"
