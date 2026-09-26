FROM axllent/mailpit:v1.31.2

LABEL org.opencontainers.image.title="SmartPot Mail" \
      org.opencontainers.image.description="Mailpit de SmartPot con autenticación SMTP e interfaz protegida" \
      org.opencontainers.image.source="https://github.com/SmartPotTech/SmartPot-Mail" \
      org.opencontainers.image.licenses="MIT"

COPY --chmod=755 entrypoint.sh /usr/local/bin/smartpot-entrypoint.sh

USER 1000:1000

EXPOSE 1025 8025

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/mailpit", "readyz"]

ENTRYPOINT ["/usr/local/bin/smartpot-entrypoint.sh"]
