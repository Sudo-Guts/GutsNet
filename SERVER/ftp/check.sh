#!/usr/bin/env bash
# GutsNet - verificacion LOCAL de FTPS. No modifica el sistema.
set -Eeuo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
ftp_root="/home/gutsnet-shared/ftp"
exchange="$ftp_root/intercambio"
user="gutsftp"
media=/home/gutsnet-shared/peliculas
unified=0
if [[ -f /etc/gutsnet/media-unificada ]]; then
    user=gutsjail
    unified=1
fi
group="gutsnet-files"
[[ -f /etc/vsftpd.conf ]] || fail "Falta /etc/vsftpd.conf"
[[ -f /etc/vsftpd.gutsnet-users ]] || fail "Falta lista de autorizados"
grep -qx "$user" /etc/vsftpd.gutsnet-users || fail "$user no esta autorizado"
getent passwd "$user" >/dev/null || fail "Usuario $user inexistente"
id -nG "$user" | tr ' ' '\n' | grep -qx "$group" || fail "$user no pertenece a $group"
[[ -d "$ftp_root" && ! -L "$ftp_root" ]] || fail "Directorio chroot incorrecto"
[[ "$(stat -c '%U:%G' "$ftp_root")" == "root:root" ]] || fail "El chroot debe ser root:root"
mode="$(stat -c '%a' "$ftp_root")"
(( (8#$mode & 0022) == 0 )) || fail "Chroot escribible por grupo/otros"
[[ -d "$exchange" && ! -L "$exchange" ]] || fail "Falta intercambio"
[[ "$(stat -c '%U:%G' "$exchange")" == "root:$group" ]] || fail "Propietario de intercambio incorrecto"
[[ -s /etc/ssl/certs/gutsnet.crt && -s /etc/ssl/private/gutsnet.key ]] || fail "Faltan certificados"
systemctl is-active --quiet vsftpd || fail "Servicio vsftpd inactivo"
ok "Servicio vsftpd activo"
if ((unified)); then
    mountpoint -q "$exchange" || fail "FTPS no tiene montaje de biblioteca"
    [[ "$(stat -Lc '%d:%i' "$exchange")" == "$(stat -Lc '%d:%i' "$media")" ]] || fail "FTPS no apunta a Cinema"
    ok "FTPS comparte la biblioteca de Cinema y SSH Jail"
else
    ok "FTPS con intercambio separado (pendiente de unificacion)"
fi
ss -ltn '( sport = :21 )'
printf '\nPendiente: probar la subida y descarga con un cliente FTPS remoto.\n'
