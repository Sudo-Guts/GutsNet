#!/usr/bin/env bash
# Comprueba Apache, TLS, permisos y autenticacion sin pedir contrasena.
set -Eeuo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
[[ "$EUID" -eq 0 ]] || fail 'Usa sudo para revisar la configuracion y permisos.'
for command in apache2ctl openssl curl runuser; do command -v "$command" >/dev/null || fail "Falta $command"; done
cert=/etc/ssl/certs/gutsnet.crt
key=/etc/ssl/private/gutsnet.key
ca=/etc/ssl/certs/gutsnet-ca.crt
auth=/etc/gutsnet/cinema.htpasswd
storage=/home/gutsnet-shared/peliculas
for path in "$cert" "$key" "$auth"; do [[ -s "$path" && ! -L "$path" ]] || fail "Falta archivo regular: $path"; done
[[ -d "$storage" && ! -L "$storage" ]] || fail 'Falta la carpeta privada de peliculas.'
[[ "$(stat -c '%U' "$key")" == root ]] || fail 'La llave TLS debe pertenecer a root.'
mode="$(stat -c '%a' "$key")"
(( (8#$mode & 0077) == 0 )) || fail 'La llave TLS permite acceso a grupo u otros.'
mode="$(stat -c '%a' "$auth")"
(( (8#$mode & 0007) == 0 )) || fail 'El archivo de cuentas permite acceso a otros usuarios.'
runuser -u www-data -- test -r "$auth" || fail 'Apache no puede leer las cuentas.'
runuser -u www-data -- test -r "$storage" && runuser -u www-data -- test -x "$storage" || fail 'Apache no puede leer las peliculas.'
apache2ctl configtest
openssl x509 -in "$cert" -noout -checkend 86400 >/dev/null || fail 'El certificado vence pronto o esta vencido.'
openssl x509 -in "$cert" -noout -checkhost gutsnet.test >/dev/null || fail 'El certificado no cubre gutsnet.test.'
trust="$cert"
if [[ -r "$ca" ]] && openssl verify -CAfile "$ca" "$cert" >/dev/null 2>&1; then trust="$ca"; fi
ok 'Configuracion, certificado y permisos de Apache'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
code="$(curl --noproxy '*' --silent --show-error --max-time 15 -o /dev/null \
    -D "$tmp/http.headers" -w '%{http_code}' -H 'Host: gutsnet.test' http://127.0.0.1/cinema/)"
[[ "$code" == 302 ]] || fail "HTTP /cinema/ respondio $code; se esperaba 302 hacia HTTPS."
headers="$(< "$tmp/http.headers")"
[[ "${headers,,}" == *'location: https://gutsnet.test/cinema/'* ]] || fail 'La redireccion no apunta a HTTPS.'
ok 'HTTP redirige Cinema a HTTPS'

for path in /cinema /cinema/ /cinema/media/Prueba_GutsCinema.mp4; do
    code="$(curl --noproxy '*' --silent --show-error --max-time 15 \
        --cacert "$trust" --resolve gutsnet.test:443:127.0.0.1 \
        -D "$tmp/auth.headers" -o /dev/null -w '%{http_code}' "https://gutsnet.test$path")"
    [[ "$code" == 401 ]] || fail "$path respondio $code sin credenciales; se esperaba 401."
    headers="$(< "$tmp/auth.headers")"
    [[ "${headers,,}" == *'www-authenticate: basic'* ]] || fail 'Falta el desafio de autenticacion Basic.'
done
ok 'Catalogo y URL directa de video exigen credenciales por HTTPS'
printf 'GutsCinema: https://gutsnet.test/cinema/\n'
