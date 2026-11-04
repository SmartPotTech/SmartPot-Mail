#!/bin/sh
# Prueba de humo: comprueba que la imagen arranca, rechaza el acceso anónimo
# tanto en la interfaz web como en SMTP, y entrega un correo autenticado que
# luego aparece en la API de Mailpit.
set -eu

IMAGE="${1:-smartpot-mail:ci}"
NAME="smartpot-mail-smoke"
SMTP_USER="smartpot"
SMTP_PASS="smoke-smtp-password-1234"
UI_USER="admin"
UI_PASS="smoke-ui-password-1234"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  -p 127.0.0.1:11025:1025 -p 127.0.0.1:18025:8025 \
  -e MAIL_USERNAME="$SMTP_USER" -e MAIL_PASSWORD="$SMTP_PASS" \
  -e MAILPIT_UI_USERNAME="$UI_USER" -e MAILPIT_UI_PASSWORD="$UI_PASS" \
  "$IMAGE" >/dev/null

for _ in $(seq 1 20); do
  docker exec "$NAME" /mailpit readyz >/dev/null 2>&1 && break
  sleep 1
done

fail=0
check() { if eval "$2"; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

check "/readyz is public for health checks" \
  '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18025/readyz)" = "200" ]'

check "web UI requires credentials (401 without user)" \
  '[ "$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:18025/api/v1/messages)" = "401" ]'

check "SMTP rejects shipping without AUTH" \
  '! curl -s --url smtp://127.0.0.1:11025 --mail-from a@b.local --mail-rcpt c@b.local -T - <<EOF >/dev/null 2>&1
Subject: sin auth

no debe entrar
EOF'

check "SMTP delivers an authenticated email and the API reads it" '
  curl -fsS --url smtp://127.0.0.1:11025 \
    --user "$SMTP_USER:$SMTP_PASS" \
    --mail-from no-reply@smartpot.local \
    --mail-rcpt jardin@smartpot.local \
    -T - <<EOF
From: SmartPot <no-reply@smartpot.local>
To: jardin@smartpot.local
Subject: Verification code

Your code is 482910.
EOF
  curl -fsS -u "$UI_USER:$UI_PASS" http://127.0.0.1:18025/api/v1/messages | grep -q "482910"
'

exit "$fail"
