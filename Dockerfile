FROM axllent/mailpit:latest

LABEL maintainer="smartpottech@gmail.com" \
      version="1.0.0" \
      description="Imagen personalizada de MailPit para SmartPot" \
      license="MIT" \
      created="2025-01-11" \
      repository="https://github.com/SmartPotTech/SmartPot-Mail" \
      environment="local"

# Variables de entorno por defecto
ENV MAIL_USERNAME=smartpotadmin@example.com
ENV MAIL_PASSWORD=password123
ENV MP_SMTP_AUTH=true
ENV MP_SMTP_AUTH_FILE=/etc/mailpit/authfile

# Copiar el entrypoint personalizado
COPY entrypoint.sh /opt/smartpot/entrypoint.sh
RUN chmod +x /opt/smartpot/entrypoint.sh

EXPOSE 1025 8025

ENTRYPOINT ["/opt/smartpot/entrypoint.sh"]