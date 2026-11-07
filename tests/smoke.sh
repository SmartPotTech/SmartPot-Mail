#!/bin/sh
# Prueba de humo: arranca la imagen endurecida, comprueba que la interfaz web y
# SMTP rechazan el acceso anónimo, entrega un correo autenticado real y lo
# localiza por asunto y destinatario en la API de Mailpit, incluido el cuerpo.
#
# Variables (todas opcionales; los valores por defecto son los de este humo):
#   SMOKE_EXTERNAL=1     usa un Mailpit ya arrancado en SMTP_HOST/MAILPIT_API_URL
#                        en lugar de crear el contenedor desechable.
#   SMTP_HOST            host SMTP (127.0.0.1).
#   SMTP_PORT            puerto SMTP publicado (11025).
#   SMTP_AUTH            mecanismo anunciado: LOGIN (por defecto) o PLAIN.
#   SMTP_USER            usuario SMTP (smartpot).
#   SMTP_PASSWORD        clave SMTP (smoke-smtp-password-1234).
#   SMTP_FROM            remitente (no-reply@smartpot.local).
#   SMTP_TO              destinatario (jardin@smartpot.local).
#   MAILPIT_API_URL      API y UI de Mailpit (http://127.0.0.1:18025).
#   MAILPIT_UI_USERNAME  usuario de la API (admin).
#   MAILPIT_UI_PASSWORD  clave de la API (smoke-ui-password-1234).
#   PYTHON               intérprete Python 3 (python3 o python).
#
# El asunto lleva un identificador único por ejecución y el trap borra solo los
# mensajes de esa ejecución mediante DELETE /api/v1/search, así que repetirlo no
# acumula correos ni depende de ejecuciones anteriores.
set -eu

IMAGE="${1:-${SMOKE_IMAGE:-smartpot-mail:ci}}"
NAME="${SMOKE_CONTAINER_NAME:-smartpot-mail-smoke}"
SMOKE_EXTERNAL="${SMOKE_EXTERNAL:-0}"

SMTP_HOST="${SMTP_HOST:-127.0.0.1}"
SMTP_PORT="${SMTP_PORT:-11025}"
SMTP_AUTH="${SMTP_AUTH:-LOGIN}"
SMTP_USER="${SMTP_USER:-smartpot}"
SMTP_PASSWORD="${SMTP_PASSWORD:-smoke-smtp-password-1234}"
SMTP_FROM="${SMTP_FROM:-no-reply@smartpot.local}"
SMTP_TO="${SMTP_TO:-jardin@smartpot.local}"
MAILPIT_API_URL="${MAILPIT_API_URL:-http://127.0.0.1:18025}"
MAILPIT_UI_USERNAME="${MAILPIT_UI_USERNAME:-admin}"
MAILPIT_UI_PASSWORD="${MAILPIT_UI_PASSWORD:-smoke-ui-password-1234}"

RUN_ID="$(date +%s)-$$"
SUBJECT="SmartPot smoke test $RUN_ID"
TOKEN="482910"
BODY="Your verification code is $TOKEN (run $RUN_ID)."

SMTP_AUTH="$(printf '%s' "$SMTP_AUTH" | tr '[:lower:]' '[:upper:]')"
case "$SMTP_AUTH" in
  TRUE) SMTP_AUTH="LOGIN" ;;
  LOGIN | PLAIN) ;;
  *)
    echo "SMTP_AUTH must be LOGIN or PLAIN, got '$SMTP_AUTH'" >&2
    exit 2
    ;;
esac

if [ -z "${PYTHON:-}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
  else
    echo "Python 3 is required to send and verify the email" >&2
    exit 2
  fi
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 2
fi
if [ "$SMOKE_EXTERNAL" != "1" ] && ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required unless SMOKE_EXTERNAL=1" >&2
  exit 2
fi

WORK="$(mktemp -d)"
STATE_DIR="$WORK/state"
mkdir -p "$STATE_DIR"

cleanup_messages() {
  "$PYTHON" "$WORK/api.py" cleanup >/dev/null 2>&1 || true
}

cleanup() {
  cleanup_messages
  if [ "$SMOKE_EXTERNAL" != "1" ]; then
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

# Cliente de la API: localiza el mensaje por asunto y destinatario, comprueba
# el cuerpo y borra únicamente los mensajes de esta ejecución.
cat > "$WORK/api.py" <<'PY'
import base64
import json
import os
import pathlib
import sys
import urllib.parse
import urllib.request

API = os.environ["MAILPIT_API_URL"].rstrip("/")
AUTH = base64.b64encode(
    ("%s:%s" % (os.environ["MAILPIT_UI_USERNAME"], os.environ["MAILPIT_UI_PASSWORD"])).encode()
).decode()
SUBJECT = os.environ["SMOKE_SUBJECT"]
RECIPIENT = os.environ["SMTP_TO"]
TOKEN = os.environ["SMOKE_TOKEN"]
RUN_ID = os.environ["SMOKE_RUN_ID"]
STATE = pathlib.Path(os.environ["SMOKE_STATE_DIR"])


def request(path, method="GET"):
    req = urllib.request.Request(API + path, method=method, headers={"Authorization": "Basic " + AUTH})
    with urllib.request.urlopen(req, timeout=15) as response:
        payload = response.read().decode("utf-8")
    # DELETE responde text/plain; las consultas de mensajes, JSON.
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return {"raw": payload}


def search():
    query = urllib.parse.urlencode({"query": 'subject:"%s"' % SUBJECT, "limit": 50})
    return request("/api/v1/search?" + query)


def message_id():
    path = STATE / "message_id"
    if not path.exists():
        raise SystemExit("no message ID was recorded by the find step")
    return path.read_text(encoding="utf-8").strip()


mode = sys.argv[1] if len(sys.argv) > 1 else "find"

if mode == "find":
    data = search()
    matches = [
        message
        for message in data.get("messages", [])
        if message.get("Subject") == SUBJECT
        and RECIPIENT in [address.get("Address") for address in message.get("To", [])]
    ]
    if not matches:
        raise SystemExit(
            "no message with subject %r for %s (search returned %s)"
            % (SUBJECT, RECIPIENT, data.get("messages_count", 0))
        )
    (STATE / "message_id").write_text(matches[0]["ID"], encoding="utf-8")
elif mode == "body":
    identifier = message_id()
    detail = request("/api/v1/message/" + urllib.parse.quote(identifier, safe=""))
    body = (detail.get("Text") or "") + "\n" + (detail.get("HTML") or "")
    missing = [value for value in (TOKEN, RUN_ID) if value not in body]
    if missing:
        raise SystemExit("message %s does not contain %s" % (identifier, ", ".join(missing)))
elif mode == "cleanup":
    query = urllib.parse.urlencode({"query": 'subject:"%s"' % SUBJECT})
    request("/api/v1/search?" + query, method="DELETE")
    data = search()
    if data.get("messages_count", 0) != 0:
        raise SystemExit("test messages were not removed: %s left" % data.get("messages_count"))
else:
    raise SystemExit("unknown mode: " + mode)
PY

export MAILPIT_API_URL MAILPIT_UI_USERNAME MAILPIT_UI_PASSWORD
export SMTP_TO SMOKE_SUBJECT="$SUBJECT" SMOKE_TOKEN="$TOKEN" SMOKE_RUN_ID="$RUN_ID" SMOKE_STATE_DIR="$STATE_DIR"

fail=0
check() {
  description=$1
  shift
  if "$@"; then
    echo "OK   $description"
  else
    echo "FAIL $description"
    fail=1
  fi
}

http_code() {
  curl -s -o /dev/null -w '%{http_code}' "$@"
}

api_is_ready() {
  curl -fsS "${MAILPIT_API_URL%/}/readyz" >/dev/null 2>&1
}

smtp_without_auth_is_rejected() {
  "$PYTHON" - "$SMTP_HOST" "$SMTP_PORT" "$SMTP_FROM" "$SMTP_TO" <<'PY'
import smtplib
import sys

host, port, sender, recipient = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
smtp = smtplib.SMTP(host, port, timeout=15)
try:
    smtp.ehlo()
    smtp.sendmail(sender, [recipient], "Subject: no auth\r\n\r\nmust not be delivered")
except (smtplib.SMTPAuthenticationError, smtplib.SMTPSenderRefused) as error:
    # Mailpit responde 530 al MAIL FROM anónimo y 535 si la clave es incorrecta.
    raise SystemExit(0 if error.smtp_code in (530, 535) else 1)
else:
    raise SystemExit("SMTP accepted a message without AUTH")
finally:
    try:
        smtp.quit()
    except OSError:
        pass
PY
}

smtp_with_a_wrong_password_is_rejected() {
  "$PYTHON" - "$SMTP_HOST" "$SMTP_PORT" "$SMTP_USER" "$SMTP_PASSWORD" <<'PY'
import smtplib
import sys

host, port, user, password = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
smtp = smtplib.SMTP(host, port, timeout=15)
try:
    smtp.ehlo()
    smtp.login(user, password + "-wrong")
except smtplib.SMTPAuthenticationError as error:
    raise SystemExit(0 if error.smtp_code == 535 else 1)
else:
    raise SystemExit("SMTP accepted a wrong password")
finally:
    try:
        smtp.quit()
    except OSError:
        pass
PY
}

send_with_swaks() {
  swaks --server "$SMTP_HOST:$SMTP_PORT" \
    --auth "$SMTP_AUTH" --auth-user "$SMTP_USER" --auth-password "$SMTP_PASSWORD" \
    --from "$SMTP_FROM" --to "$SMTP_TO" \
    --header "Subject: $SUBJECT" --body "$BODY" --timeout 15 >/dev/null
}

send_with_python() {
  "$PYTHON" - "$SMTP_HOST" "$SMTP_PORT" "$SMTP_AUTH" "$SMTP_USER" "$SMTP_PASSWORD" \
    "$SMTP_FROM" "$SMTP_TO" "$SUBJECT" "$BODY" <<'PY'
import smtplib
import sys

host, port, mechanism, user, password = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
sender, recipient, subject, body = sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9]
smtp = smtplib.SMTP(host, port, timeout=15)
try:
    smtp.ehlo()
    if mechanism == "PLAIN":
        import base64

        credentials = base64.b64encode(("\0%s\0%s" % (user, password)).encode()).decode()
        code, response = smtp.docmd("AUTH", "PLAIN " + credentials)
        if code != 235:
            raise SystemExit("SMTP AUTH PLAIN failed: %s %s" % (code, response.decode(errors="replace")))
    else:
        smtp.login(user, password)
    message = (
        "From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\n"
        "Content-Type: text/plain; charset=utf-8\r\n\r\n%s\r\n" % (sender, recipient, subject, body)
    )
    smtp.sendmail(sender, [recipient], message.encode("utf-8"))
finally:
    try:
        smtp.quit()
    except OSError:
        pass
PY
}

send_authenticated_email() {
  if command -v swaks >/dev/null 2>&1; then
    send_with_swaks
  else
    send_with_python
  fi
}

logs_do_not_leak_credentials() {
  logs="$(docker logs "$NAME" 2>&1 || true)"
  case "$logs" in
    *"$SMTP_PASSWORD"* | *"$MAILPIT_UI_PASSWORD"*) return 1 ;;
  esac
  return 0
}

if [ "$SMOKE_EXTERNAL" != "1" ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" \
    --read-only --cap-drop ALL --security-opt no-new-privileges \
    --tmpfs /tmp:rw,noexec,nosuid,size=16m \
    -p 127.0.0.1:11025:1025 -p 127.0.0.1:18025:8025 \
    -e MAIL_USERNAME="$SMTP_USER" -e MAIL_PASSWORD="$SMTP_PASSWORD" \
    -e MAILPIT_UI_USERNAME="$MAILPIT_UI_USERNAME" -e MAILPIT_UI_PASSWORD="$MAILPIT_UI_PASSWORD" \
    "$IMAGE" >/dev/null
fi

ready=0
for _ in $(seq 1 30); do
  if api_is_ready; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL Mailpit did not become ready at $MAILPIT_API_URL" >&2
  if [ "$SMOKE_EXTERNAL" != "1" ]; then
    docker logs "$NAME" 2>&1 | tail -40 || true
  fi
  exit 1
fi

check "/readyz is public for health checks" api_is_ready

check "web UI requires credentials (401 without user)" test "$(http_code "$MAILPIT_API_URL/api/v1/messages")" = "401"

check "web UI rejects wrong credentials (401)" \
  test "$(http_code -u "$MAILPIT_UI_USERNAME:wrong-password" "$MAILPIT_API_URL/api/v1/messages")" = "401"

check "SMTP rejects mail without AUTH (530/535)" smtp_without_auth_is_rejected

check "SMTP rejects a wrong password (535)" smtp_with_a_wrong_password_is_rejected

check "SMTP delivers an authenticated email" send_authenticated_email

check "API finds the message by subject and recipient" "$PYTHON" "$WORK/api.py" find

check "message body contains the expected verification code" "$PYTHON" "$WORK/api.py" body

check "test messages are removed by subject" "$PYTHON" "$WORK/api.py" cleanup

if [ "$SMOKE_EXTERNAL" != "1" ]; then
  check "container logs do not leak credentials" logs_do_not_leak_credentials
fi

exit "$fail"
