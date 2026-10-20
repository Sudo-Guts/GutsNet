#!/usr/bin/env bash
# Prueba autenticada: no escribe la contrasena en archivos ni argumentos.
set -Eeuo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
account=cine
password_stdin=0
while (($#)); do
    case "$1" in
        --user) (($# >= 2)) || fail 'Falta usuario'; account="$2"; shift 2 ;;
        --password-stdin) password_stdin=1; shift ;;
        *) fail 'Uso: bash SERVER/cinema/test.sh [--user cine] [--password-stdin]' ;;
    esac
done
[[ "$account" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$ ]] || fail 'Nombre de cuenta no valido.'
for command in curl openssl python3; do command -v "$command" >/dev/null || fail "Falta $command"; done
cert=/etc/ssl/certs/gutsnet.crt
ca=/etc/ssl/certs/gutsnet-ca.crt
[[ -r "$cert" ]] || fail 'Falta el certificado. Instala GutsCinema primero.'
trust="$cert"
if [[ -r "$ca" ]] && openssl verify -CAfile "$ca" "$cert" >/dev/null 2>&1; then trust="$ca"; fi
if [[ "$password_stdin" == 1 ]]; then
    IFS= read -r password || fail 'No se recibio la contrasena por stdin.'
else
    IFS= read -r -s -p "Contrasena de GutsCinema ($account): " password < /dev/tty
    printf '\n'
fi
[[ -n "$password" && "$password" != *$'\r'* ]] || fail 'Contrasena no valida.'
escaped="${password//\\/\\\\}"
escaped="${escaped//\"/\\\"}"
tmp="$(mktemp -d)"
trap 'unset password escaped; rm -rf "$tmp"' EXIT
options=(--noproxy '*' --silent --show-error --connect-timeout 5 --max-time 30 \
    --cacert "$trust" --resolve gutsnet.test:443:127.0.0.1)
request() {
    printf 'user = "%s:%s"\n' "$account" "$escaped" | curl --config - "${options[@]}" "$@"
}
code="$(request -D "$tmp/catalog.headers" -o "$tmp/catalog.html" -w '%{http_code}' https://gutsnet.test/cinema/)"
[[ "$code" == 200 ]] || fail "El catalogo respondio $code. Revisa la cuenta y contrasena."
python3 - "$tmp/catalog.html" <<'PY'
from pathlib import Path
import sys
page=Path(sys.argv[1]).read_text()
assert '<?php' not in page, 'Apache esta entregando el codigo PHP sin ejecutarlo'
assert 'data-cinema-catalog' in page and '<h1' in page, 'No se recibio el catalogo de GutsCinema'
PY
ok 'Credenciales correctas: catalogo PHP disponible por HTTPS'
media="$(python3 - "$tmp/catalog.html" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys
class Movies(HTMLParser):
    def handle_starttag(self, tag, attrs):
        value=dict(attrs).get('src', '')
        if tag == 'source' and value.startswith('/cinema/media/'):
            self.refs.append(value)
parser=Movies()
parser.refs=[]
parser.feed(Path(sys.argv[1]).read_text())
if not parser.refs:
    raise SystemExit('El catalogo esta vacio. Agrega un video antes de probar la reproduccion.')
print(parser.refs[0])
PY
)"
code="$(curl "${options[@]}" -o /dev/null -w '%{http_code}' "https://gutsnet.test$media")"
[[ "$code" == 401 ]] || fail "La URL directa no esta protegida: respondio $code sin credenciales."
ok 'La URL del video tambien requiere autenticacion'
code="$(request --range 0-15 -D "$tmp/range.headers" -o "$tmp/range.bin" \
    -w '%{http_code}' "https://gutsnet.test$media")"
[[ "$code" == 206 ]] || fail "El video respondio $code; se esperaba 206 Partial Content."
[[ "$(wc -c < "$tmp/range.bin")" -eq 16 ]] || fail 'El rango del video no contiene los 16 bytes solicitados.'
headers="$(< "$tmp/range.headers")"
[[ "${headers,,}" == *'content-range: bytes 0-15/'* ]] || fail 'Falta Content-Range en la respuesta.'
ok 'Reproduccion y desplazamiento: solicitudes Range (HTTP 206)'
here="$(cd -- "$(dirname -- "$0")" && pwd)"
printf '%s\n' "$password" | python3 "$here/test-management.py" --user "$account" --ca "$trust"
printf 'Pruebas de GutsCinema completadas.\n'
