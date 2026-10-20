#!/usr/bin/env bash
# GutsNet - instalacion explicita de FTPS en Ubuntu.
# Este script NO se ejecuta automaticamente con git pull.
set -Eeuo pipefail

here="$(cd -- "$(dirname -- "$0")" && pwd)"
source_conf="$here/vsftpd.conf"
root="/home/gutsnet-shared"
ftp_root="$root/ftp"
exchange="$ftp_root/intercambio"
ftp_user="gutsftp"
share_group="gutsnet-files"
ftp_conf="/etc/vsftpd.conf"
allowlist="/etc/vsftpd.gutsnet-users"
cert="/etc/ssl/certs/gutsnet.crt"
key="/etc/ssl/private/gutsnet.key"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '[GutsNet FTP] %s\n' "$*"; }

usage() {
    cat <<'HELP'
Uso:
  bash SERVER/ftp/install.sh --check
  sudo bash SERVER/ftp/install.sh --install

--check: verifica requisitos sin cambiar nada.
--install: instala y configura FTPS explicitamente (requiere sudo).
HELP
}

preflight() {
    [[ -f "$source_conf" ]] || die "No existe $source_conf"
    [[ -s "$cert" ]] || die "Falta certificado TLS: $cert"
    [[ -s "$key" ]] || die "Falta llave privada TLS: $key"
    command -v openssl >/dev/null || die "Falta openssl"
    openssl x509 -in "$cert" -noout >/dev/null 2>&1 ||
        die "El certificado TLS no es valido"
    [[ -x /usr/sbin/nologin ]] || die "Falta /usr/sbin/nologin"
    [[ ! -L "$root" ]] || die "$root es un enlace simbolico"
    [[ ! -L "$ftp_root" ]] || die "$ftp_root es un enlace simbolico"
    [[ ! -L "$exchange" ]] || die "$exchange es un enlace simbolico"

    if [[ -e "$root" && ! -d "$root" ]]; then
        die "$root no es un directorio"
    fi
    if [[ -e "$ftp_root" ]]; then
        [[ -d "$ftp_root" ]] || die "$ftp_root no es un directorio"
        [[ "$(stat -c '%U:%G' "$ftp_root")" == "root:root" ]] ||
            die "$ftp_root debe ser root:root"
        local mode
        mode="$(stat -c '%a' "$ftp_root")"
        (( (8#$mode & 0022) == 0 )) ||
            die "$ftp_root permite escritura de grupo/otros"
    fi
    if [[ -e "$exchange" && ! -d "$exchange" ]]; then
        die "$exchange no es un directorio"
    fi

    if id "$ftp_user" >/dev/null 2>&1; then
        local home shell
        home="$(getent passwd "$ftp_user" | cut -d: -f6)"
        shell="$(getent passwd "$ftp_user" | cut -d: -f7)"
        [[ "$home" == "$ftp_root" && "$shell" == /usr/sbin/nologin ]] ||
            die "El usuario $ftp_user existe con home/shell incompatibles"
        if id -nG "$ftp_user" | tr ' ' '\n' | grep -qx sudo; then
            die "$ftp_user pertenece a sudo"
        fi
    fi
}

check_status() {
    info "Modo --check: no se modificara el sistema."
    preflight
    info "Certificado de GutsNet: OK"
    if command -v vsftpd >/dev/null; then
        info "vsftpd instalado: si"
    else
        info "vsftpd instalado: pendiente"
    fi
    if id "$ftp_user" >/dev/null 2>&1; then
        info "Usuario FTP: existente"
    else
        info "Usuario FTP: pendiente"
    fi
    [[ ! -d "$root/peliculas" ]] ||
        info "Cinema detectado: $root/peliculas no se modificara"
    info "Puertos de FTPS: 21/tcp y 40000-40010/tcp"
}

do_install() {
    [[ "$EUID" -eq 0 ]] || die "Ejecuta con sudo."
    preflight
    command -v apt-get >/dev/null || die "Se necesita Ubuntu/Debian con apt-get."

    info "Instalando vsftpd..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y vsftpd

    # Nunca cambiar permisos de peliculas ni de un directorio compartido existente.
    if [[ ! -e "$root" ]]; then
        install -d -o root -g root -m 755 "$root"
    fi
    if [[ ! -e "$ftp_root" ]]; then
        install -d -o root -g root -m 755 "$ftp_root"
    fi

    if ! getent group "$share_group" >/dev/null; then
        groupadd --system "$share_group"
    fi

    if ! id "$ftp_user" >/dev/null 2>&1; then
        useradd --no-create-home --home-dir "$ftp_root" \
            --shell /usr/sbin/nologin --user-group \
            --groups "$share_group" "$ftp_user"
    else
        usermod --append --groups "$share_group" "$ftp_user"
    fi

    if [[ ! -e "$exchange" ]]; then
        install -d -o root -g "$share_group" -m 2770 "$exchange"
    else
        [[ "$(stat -c '%U:%G' "$exchange")" == "root:$share_group" ]] ||
            die "$exchange ya existe con dueno o grupo diferente"
    fi
    chmod 2770 "$exchange"

    if [[ -e "$ftp_conf" ]]; then
        local backup
        backup="$ftp_conf.gutsnet-backup-$(date +%Y%m%d-%H%M%S)-$$"
        cp -a "$ftp_conf" "$backup"
        info "Respaldo del vsftpd anterior: $backup"
    fi
    printf '%s\n' "$ftp_user" > "$allowlist"
    chown root:root "$allowlist"
    chmod 600 "$allowlist"
    install -o root -g root -m 644 "$source_conf" "$ftp_conf"

    systemctl enable vsftpd
    systemctl restart vsftpd
    systemctl is-active --quiet vsftpd ||
        die "vsftpd no quedo activo. Ejecuta: journalctl -u vsftpd -n 50"

    info "Instalacion FTPS completada. Peliculas, Apache y SSH intactos."
    info "SIGUIENTE: sudo passwd $ftp_user (crea su contrasena sin mostrarla)"
    info "DESPUES: sudo bash SERVER/ftp/check.sh"
}

if [[ "$#" -ne 1 ]]; then
    usage
    exit 2
fi
case "$1" in
    --check) check_status ;;
    --install) do_install ;;
    -h|--help) usage ;;
    *) usage; exit 2 ;;
esac
