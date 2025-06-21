FROM axllent/mailpit:latest

# Establece variables de entorno para autenticación
ENV MP_SMTP_AUTH=true
ENV MP_SMTP_AUTH_FILE=/etc/mailpit/authfile

# Copia archivo de autenticación al contenedor
COPY authfile /etc/mailpit/authfile