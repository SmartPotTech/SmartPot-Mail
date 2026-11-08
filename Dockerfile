FROM axllent/mailpit:v1.33.0

LABEL org.opencontainers.image.title="SmartPot Mail" \
      org.opencontainers.image.description="Lightweight SMTP server and web UI for SmartPot emails (Mailpit, authenticated)" \
      org.opencontainers.image.source="https://github.com/SmartPotTech/SmartPot-Mail" \
      org.opencontainers.image.licenses="MIT"

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

EXPOSE 1025 8025

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/mailpit", "readyz"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
