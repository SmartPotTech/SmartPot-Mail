#!/bin/sh
set -eu

: "${MAIL_USERNAME:?Missing MAIL_USERNAME for SMTP authentication}"
: "${MAIL_PASSWORD:?Missing MAIL_PASSWORD for SMTP authentication}"
: "${MAILPIT_UI_USERNAME:?Missing MAILPIT_UI_USERNAME to protect the web UI}"
: "${MAILPIT_UI_PASSWORD:?Missing MAILPIT_UI_PASSWORD to protect the web UI}"

for secret in "$MAIL_PASSWORD" "$MAILPIT_UI_PASSWORD"; do
  if [ "${#secret}" -lt 12 ]; then
    echo "Mailpit passwords must be at least 12 characters long."
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

echo "Mailpit started with SMTP authentication (user $MAIL_USERNAME) and protected UI (user $MAILPIT_UI_USERNAME)."
exec /mailpit --smtp "0.0.0.0:1025" --listen "0.0.0.0:8025" "$@"
