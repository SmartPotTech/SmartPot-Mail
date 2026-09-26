#!/bin/sh
# Arranca la imagen endurecida y valida la autenticación SMTP y de la interfaz web.
set -eu

IMAGE="${1:-smartpot-mail:ci}"
NAME="smartpot-mail-smoke"
SMTP_USER="smartpot"
SMTP_PASS="smoke-smtp-password"
UI_USER="admin"
UI_PASS="smoke-ui-password"

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -e MAIL_USERNAME="$SMTP_USER" -e MAIL_PASSWORD="$SMTP_PASS" \
  -e MAILPIT_UI_USERNAME="$UI_USER" -e MAILPIT_UI_PASSWORD="$UI_PASS" "$IMAGE" >/dev/null

for _ in $(seq 1 20); do
  [ "$(docker inspect -f '{{.State.Health.Status}}' "$NAME")" = "healthy" ] && break
  sleep 1
done

curl_in() { docker run --rm --network "container:$NAME" curlimages/curl:8.16.0 -s "$@"; }
message="From: api@smartpot.app\r\nTo: ana@example.com\r\nSubject: Prueba\r\n\r\nHola"
send() { printf "$message" | docker run --rm -i --network "container:$NAME" curlimages/curl:8.16.0 -s \
  smtp://127.0.0.1:1025 --mail-from api@smartpot.app --mail-rcpt ana@example.com --upload-file - "$@"; }

fail=0
check() { if eval "$2"; then echo "OK   $1"; else echo "FAIL $1"; fail=1; fi; }

check "el contenedor queda sano" '[ "$(docker inspect -f "{{.State.Health.Status}}" "$NAME")" = "healthy" ]'
check "la interfaz exige usuario y contraseña" '[ "$(curl_in -o /dev/null -w "%{http_code}" http://127.0.0.1:8025/api/v1/messages)" = "401" ]'
check "la interfaz acepta las credenciales" '[ "$(curl_in -o /dev/null -w "%{http_code}" -u "$UI_USER:$UI_PASS" http://127.0.0.1:8025/api/v1/messages)" = "200" ]'
check "SMTP rechaza envíos sin autenticación" '! send'
check "SMTP acepta envíos autenticados" 'send --user "$SMTP_USER:$SMTP_PASS"'
check "el mensaje llega al buzón" 'curl_in -u "$UI_USER:$UI_PASS" http://127.0.0.1:8025/api/v1/messages | grep -q Prueba'
check "las contraseñas no aparecen en los logs" '! docker logs "$NAME" 2>&1 | grep -q -e "$SMTP_PASS" -e "$UI_PASS"'

exit "$fail"
