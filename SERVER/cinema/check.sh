#!/usr/bin/env bash
# Comprueba Apache, TLS, permisos y autenticacion sin pedir contrasena.
set -Eeuo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
[[ "$EUID" -eq 0 ]] || fail 'Usa sudo para revisar la configuracion y permisos.'
for command in apache2ctl openssl curl runuser python3; do command -v "$command" >/dev/null || fail "Falta $command"; done
here="$(cd -- "$(dirname -- "$0")" && pwd)"
cert=/etc/ssl/certs/gutsnet.crt
key=/etc/ssl/private/gutsnet.key
ca=/etc/ssl/certs/gutsnet-ca.crt
auth=/etc/gutsnet/cinema.htpasswd
storage=/home/gutsnet-shared/peliculas
incoming=/home/gutsnet-shared/.cinema-incoming
for path in "$cert" "$key" "$auth"; do [[ -s "$path" && ! -L "$path" ]] || fail "Falta archivo regular: $path"; done
[[ -d "$storage" && ! -L "$storage" ]] || fail 'Falta la carpeta privada de peliculas.'
[[ "$(stat -c '%U' "$key")" == root ]] || fail 'La llave TLS debe pertenecer a root.'
mode="$(stat -c '%a' "$key")"
(( (8#$mode & 0077) == 0 )) || fail 'La llave TLS permite acceso a grupo u otros.'
mode="$(stat -c '%a' "$auth")"
(( (8#$mode & 0007) == 0 )) || fail 'El archivo de cuentas permite acceso a otros usuarios.'
# Bash respeta ACL y grupos suplementarios, a diferencia de test en uutils 0.10.
runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -r "$auth" || fail 'Apache no puede leer las cuentas.'
runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -r "$storage" && runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -x "$storage" || fail 'Apache no puede leer las peliculas.'
runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -w "$storage" || fail 'Apache no puede agregar ni eliminar archivos de Cinema. Ejecuta make install-cinema.'
[[ -d "$incoming" && ! -L "$incoming" ]] || fail 'Falta el area privada de carga. Ejecuta make install-cinema.'
runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -x "$incoming" && runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -w "$incoming" \
    || fail 'Apache no puede recibir archivos de Cinema. Ejecuta make install-cinema.'
lock="$incoming/.lock"
[[ ! -L "$lock" ]] || fail 'El bloqueo de Cinema no puede ser un enlace simbolico.'
if [[ -e "$lock" ]]; then
    [[ -f "$lock" ]] || fail 'El bloqueo de Cinema no es un archivo regular.'
    runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -w "$lock" \
        || fail 'Apache no puede abrir el bloqueo de Cinema. Ejecuta make install-cinema.'
fi
if [[ -d /run/systemd/system ]]; then
    command -v systemctl >/dev/null && command -v nsenter >/dev/null \
        || fail 'Falta systemctl o nsenter (util-linux) para comprobar el servicio de Apache.'
    apache_pid="$(systemctl show apache2.service --property=MainPID --value)"
    [[ "$apache_pid" =~ ^[1-9][0-9]*$ ]] || fail 'El servicio de Apache no esta activo.'
    for path in "$storage" "$incoming"; do
        if ! nsenter --target "$apache_pid" --mount -- runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -w "$path"; then
            systemctl show apache2.service --property=ProtectHome --property=ProtectSystem \
                --property=ReadWritePaths >&2
            fail 'El servicio de Apache ve Cinema sin escritura. Ejecuta make install-cinema para aplicar la excepcion de systemd.'
        fi
    done
    ok 'Escritura de Cinema dentro del servicio de Apache'
fi
apache2ctl configtest
openssl x509 -in "$cert" -noout -checkend 86400 >/dev/null || fail 'El certificado vence pronto o esta vencido.'
openssl x509 -in "$cert" -noout -checkhost gutsnet.test >/dev/null || fail 'El certificado no cubre gutsnet.test.'
trust="$cert"
if [[ -r "$ca" ]] && openssl verify -CAfile "$ca" "$cert" >/dev/null 2>&1; then trust="$ca"; fi
ok 'Configuracion, certificado y permisos de Apache'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 "$here/test-redirects.py"

for path in /cinema /cinema/ /cinema/manage.php /cinema/media/Prueba_GutsCinema.mp4 /cinema/media/prueba.mp3; do
    code="$(curl --noproxy '*' --silent --show-error --max-time 15 \
        --cacert "$trust" --resolve gutsnet.test:443:127.0.0.1 \
        -D "$tmp/auth.headers" -o /dev/null -w '%{http_code}' "https://gutsnet.test$path")"
    [[ "$code" == 401 ]] || fail "$path respondio $code sin credenciales; se esperaba 401."
    headers="$(< "$tmp/auth.headers")"
    [[ "${headers,,}" == *'www-authenticate: basic'* ]] || fail 'Falta el desafio de autenticacion Basic.'
done
ok 'Catalogo y URL directa de video exigen credenciales por HTTPS'
printf 'GutsCinema: https://gutsnet.test/cinema/\n'
# Una prueba local con Host:gutsnet.test no comprueba el DNS del telefono.
# Informa solo las IPv4 reales del equipo y valida su cobertura en el certificado.
while IFS= read -r address; do
    if openssl x509 -in "$cert" -noout -checkip "$address" >/dev/null 2>&1; then
        printf 'Acceso por IP (incluida en el certificado): https://%s/cinema/\n' "$address"
    else
        printf 'IP %s: el certificado existente no incluye esta direccion. Configura DNS local para gutsnet.test o un certificado con esta IP.\n' "$address"
    fi
done < <(python3 - <<'PY'
import ipaddress
import subprocess
addresses = subprocess.check_output(['hostname', '-I'], text=True).split()
for word in sorted(set(addresses)):
    address = ipaddress.ip_address(word)
    if address.version == 4 and not address.is_unspecified and not address.is_loopback:
        print(address)
PY
)
