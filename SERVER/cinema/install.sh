#!/usr/bin/env bash
# GutsCinema · instalacion explicita en Ubuntu/Debian. No se ejecuta con git pull.
set -Eeuo pipefail
umask 077

here="$(cd -- "$(dirname -- "$0")" && pwd)"
repo="$(cd -- "$here/../.." && pwd)"
shared=/home/gutsnet-shared
storage="$shared/peliculas"
incoming="$storage/.incoming"
auth_dir=/etc/gutsnet
auth_file="$auth_dir/cinema.htpasswd"
tls_dir="$auth_dir/tls"
cert=/etc/ssl/certs/gutsnet.crt
key=/etc/ssl/private/gutsnet.key
ca_cert=/etc/ssl/certs/gutsnet-ca.crt
ca_key="$tls_dir/ca.key"
account=cine
mode=""
password_stdin=0
skip_packages=0
temp=""

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '[GutsCinema] %s\n' "$*"; }
usage() {
    cat <<'HELP'
Uso: sudo bash SERVER/cinema/install.sh --install [--user cine]
     sudo bash SERVER/cinema/install.sh --check

--install          Configura Apache, HTTPS, cuenta privada y publica la web.
--check            Revisa requisitos y estado sin modificar archivos.
--user NOMBRE      Cuenta de Cinema (independiente de usuarios Linux).
--password-stdin   Lee la nueva contrasena por stdin, para automatizacion.
--skip-packages    No ejecuta APT; los requisitos deben estar instalados.
HELP
}
while (($#)); do
    case "$1" in
        --install|--check) [[ -z "$mode" ]] || fail 'Elige un solo modo'; mode="$1"; shift ;;
        --user) (($# >= 2)) || fail 'Falta el nombre de usuario'; account="$2"; shift 2 ;;
        --password-stdin) password_stdin=1; shift ;;
        --skip-packages) skip_packages=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Opcion desconocida: $1" ;;
    esac
done
[[ -n "$mode" ]] || { usage; exit 2; }
[[ "$EUID" -eq 0 ]] || fail 'Ejecuta el instalador con sudo.'
[[ "$account" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,31}$ ]] || fail 'Nombre de cuenta no valido.'

safe_paths() {
    local path
    for path in "$shared" "$storage" "$incoming" "$incoming/.lock" "$auth_dir" "$auth_file" "$tls_dir" "$cert" "$key" "$ca_cert" "$ca_key" \
        /var/www/gutsnet /var/www/gutsnet/public /var/lib/gutsnet; do
        [[ ! -L "$path" ]] || fail "No se permite un enlace simbolico en $path"
    done
    for path in "$shared" "$storage" "$incoming" "$auth_dir" "$tls_dir"; do
        [[ ! -e "$path" || -d "$path" ]] || fail "$path no es un directorio"
    done
    for path in "$auth_file" "$cert" "$key" "$ca_cert" "$ca_key" "$incoming/.lock"; do
        [[ ! -e "$path" || -f "$path" ]] || fail "$path no es un archivo regular"
    done
    [[ -f "$repo/SERVER/apache/gutsnet.conf" && -f "$repo/SERVER/apache/gutsnet-ssl.conf" ]] || fail 'Faltan VirtualHosts de GutsNet.'
    [[ -f "$repo/C0DE/web/public/cinema/index.php" ]] || fail 'Falta el catalogo PHP.'
}

if [[ "$mode" == --check ]]; then
    safe_paths
    info 'Revision sin cambios.'
    for command in apache2ctl a2enmod htpasswd openssl php rsync python3 curl make; do
        if command -v "$command" >/dev/null; then info "$command: disponible"; else info "$command: por instalar"; fi
    done
    [[ ! -f "$cert" ]] || openssl x509 -in "$cert" -noout -subject -enddate
    [[ ! -f "$auth_file" ]] || info 'Archivo de cuentas existente: se conservara.'
    [[ ! -d "$storage" ]] || info 'Carpeta de peliculas existente: se conservara.'
    exit 0
fi

safe_paths
if [[ "$skip_packages" == 0 ]]; then
    command -v apt-get >/dev/null || fail 'Este instalador necesita Ubuntu/Debian con APT.'
    info 'Instalando requisitos de Apache y PHP...'
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apache2 apache2-utils php libapache2-mod-php php-sqlite3 openssl rsync curl python3 make
fi
for command in apache2ctl a2enmod a2ensite htpasswd openssl php rsync python3 curl make runuser; do
    command -v "$command" >/dev/null || fail "Falta $command"
done
getent passwd www-data >/dev/null || fail 'No existe la cuenta de Apache www-data.'
python3 "$repo/scripts/version-web-assets.py" --check
for file in "$repo"/C0DE/web/public/cinema/*.php; do php -l "$file"; done
php -r 'exit(PHP_INT_SIZE >= 8 && extension_loaded("fileinfo") && extension_loaded("session") ? 0 : 1);' \
    || fail 'Cinema necesita PHP de 64 bits con Fileinfo y Session.'

# No se cambia la propiedad del padre compartido ni del area de FTP.
[[ -d "$shared" ]] || install -d -o root -g root -m 755 "$shared"
[[ -d "$storage" ]] || install -d -o root -g www-data -m 770 "$storage"
# La escritura se limita a esta biblioteca dedicada, fuera de la raiz web.
chown root:www-data "$storage"
chmod 0770 "$storage"
install -d -o www-data -g www-data -m 700 "$incoming"
runuser -u www-data -- test -r "$storage" && runuser -u www-data -- test -x "$storage" \
    || fail "Apache no puede leer/recorrer $storage. Revisa sus permisos sin alterar el area de FTP."
install -d -o root -g www-data -m 750 "$auth_dir"
install -d -o root -g root -m 700 "$tls_dir"
[[ -d /var/lib/gutsnet ]] || install -d -o www-data -g www-data -m 750 /var/lib/gutsnet

temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

if [[ -e "$cert" || -e "$key" ]]; then
    [[ -s "$cert" && -s "$key" ]] || fail 'El par TLS existente esta incompleto; no se sobrescribira.'
    openssl x509 -in "$cert" -noout -checkend 86400 >/dev/null || fail 'El certificado existente vencio o vence en menos de un dia.'
    openssl x509 -in "$cert" -noout -checkhost gutsnet.test >/dev/null || fail 'El certificado existente no cubre gutsnet.test.'
    cmp -s <(openssl x509 -in "$cert" -pubkey -noout) <(openssl pkey -in "$key" -passin pass: -pubout 2>/dev/null) \
        || fail 'El certificado existente y la llave no corresponden.'
    info 'Se conserva el certificado TLS existente, compartido con FTPS.'
else
    if [[ -e "$ca_cert" || -e "$ca_key" ]]; then
        [[ -s "$ca_cert" && -s "$ca_key" ]] || fail 'La CA local existente esta incompleta.'
        openssl x509 -in "$ca_cert" -noout -checkend 86400 >/dev/null || fail 'La CA local esta vencida.'
        cmp -s <(openssl x509 -in "$ca_cert" -pubkey -noout) <(openssl pkey -in "$ca_key" -passin pass: -pubout 2>/dev/null) \
            || fail 'El certificado y la llave de la CA no corresponden.'
    else
        info 'Creando la autoridad de certificacion local de GutsNet...'
        openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 3650 \
            -keyout "$ca_key" -out "$ca_cert" -subj '/CN=GutsNet Local CA' \
            -addext 'basicConstraints=critical,CA:TRUE,pathlen:0' \
            -addext 'keyUsage=critical,keyCertSign,cRLSign' >/dev/null 2>&1
        chmod 600 "$ca_key"
        chmod 644 "$ca_cert"
    fi
    # Incluye el hostname estable, loopback e IPv4 locales presentes al instalar.
    python3 - <<'PY' > "$temp/extensions.cnf"
import ipaddress
import subprocess
addresses = {'127.0.0.1'}
try:
    output = subprocess.check_output(['hostname', '-I'], text=True)
except (OSError, subprocess.CalledProcessError):
    output = ''
for word in output.split():
    try:
        address = ipaddress.ip_address(word)
        if address.version == 4 and not address.is_unspecified:
            addresses.add(str(address))
    except ValueError:
        pass
sans = 'DNS:gutsnet.test,DNS:localhost,' + ','.join('IP:' + ip for ip in sorted(addresses))
print('basicConstraints=critical,CA:FALSE')
print('keyUsage=critical,digitalSignature,keyEncipherment')
print('extendedKeyUsage=serverAuth')
print('subjectAltName=' + sans)
PY
    openssl req -new -newkey rsa:3072 -sha256 -nodes \
        -keyout "$key" -out "$temp/server.csr" -subj '/CN=gutsnet.test' >/dev/null 2>&1
    openssl x509 -req -in "$temp/server.csr" -CA "$ca_cert" -CAkey "$ca_key" \
        -CAserial "$tls_dir/ca.srl" -CAcreateserial -days 365 -sha256 \
        -extfile "$temp/extensions.cnf" -out "$cert" >/dev/null 2>&1
    chmod 600 "$key"
    chmod 644 "$cert"
    info 'Certificado HTTPS creado. La llave privada permanece fuera de Git.'
fi

if [[ -f "$auth_file" ]] && awk -F: -v user="$account" '$1 == user { found=1 } END { exit !found }' "$auth_file"; then
    info "Se conserva la contrasena existente de $account."
else
    [[ -f "$auth_file" ]] || install -o root -g www-data -m 640 /dev/null "$auth_file"
    info "Creando cuenta privada $account..."
    if [[ "$password_stdin" == 1 ]]; then
        IFS= read -r new_password || fail 'No se recibio una contrasena por stdin.'
        [[ -n "$new_password" ]] || fail 'La contrasena recibida por stdin esta vacia.'
        printf '%s\n' "$new_password" | htpasswd -i -B -C 10 "$auth_file" "$account"
        unset new_password
    else
        htpasswd -B -C 10 "$auth_file" "$account"
    fi
fi
chown root:www-data "$auth_file"
chmod 640 "$auth_file"

# Conserva respaldos de los VirtualHosts que se van a instalar.
backup="/var/backups/gutsnet/cinema/$(date +%Y%m%d-%H%M%S)-$$"
install -d -o root -g root -m 700 "$backup"
for name in gutsnet.conf gutsnet-ssl.conf; do
    target="/etc/apache2/sites-available/$name"
    [[ ! -L "$target" ]] || fail "No se permite un enlace simbolico en $target"
    [[ ! -f "$target" ]] || cp -a "$target" "$backup/$name"
    install -o root -g root -m 644 "$repo/SERVER/apache/$name" "$target"
done

a2enmod ssl auth_basic authn_file alias headers
a2ensite gutsnet.conf gutsnet-ssl.conf
apache2ctl configtest
make -C "$repo" deploy

# Una copia claramente identificada del video publico permite probar la sala.
if [[ ! -e "$storage/Prueba_GutsCinema.mp4" && ! -L "$storage/Prueba_GutsCinema.mp4" ]]; then
    install -o root -g www-data -m 640 "$repo/C0DE/web/public/assets/video/demostracion.mp4" \
        "$storage/Prueba_GutsCinema.mp4"
fi

if [[ -d /run/systemd/system ]]; then
    systemctl enable apache2
    systemctl restart apache2
    systemctl is-active --quiet apache2 || fail 'Apache no quedo activo.'
else
    apache2ctl -k graceful
fi
bash "$here/check.sh"
info 'Listo: https://gutsnet.test/cinema/'
info "Cuenta: $account. Tu contrasena no se guarda en el repositorio."
if [[ -r "$ca_cert" ]] && openssl verify -CAfile "$ca_cert" "$cert" >/dev/null 2>&1; then
    info "Certificado publico para configurar la confianza HTTPS del navegador: $ca_cert"
else
    info "Se usa tu certificado TLS existente: $cert"
fi
info 'Prueba completa: make test-cinema'
info 'Agrega MP4 y MP3 desde el formulario de la biblioteca (hasta 2 GiB).'
info 'Tambien puedes importar: sudo bash SERVER/cinema/add.sh /ruta/a/archivo.mp4'
