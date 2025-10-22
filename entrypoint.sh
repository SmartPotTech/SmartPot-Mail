#!/bin/sh
set -e

echo "Generando archivo de autenticación de MailPit..."

# Crear el archivo de autenticación dinámicamente
mkdir -p /etc/mailpit
echo "${MAIL_USERNAME}:${MAIL_PASSWORD}" > /etc/mailpit/authfile
chmod 600 /etc/mailpit/authfile

echo "Archivo de autenticación creado en /etc/mailpit/authfile"
cat /etc/mailpit/authfile

# Ejecutar MailPit con autenticación activada
echo "Iniciando MailPit..."
exec /mailpit \
  --smtp-auth \
  --smtp-auth-file=/etc/mailpit/authfile \
  --smtp-auth-allow-insecure \
  --listen ":1025" \
  --ui-bind ":8025"
