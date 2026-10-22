#!/usr/bin/env bash
# GutsNet - local SSH Jail verification (read-only).
set -Eeuo pipefail
fail() { echo "ERROR: $*" >&2; exit 1; }
ok() { echo "OK: $*"; }
user=gutsjail
jail=/home/gutsnet-jail
shared=/home/gutsnet-shared/peliculas
binary=/usr/local/bin/gutsnet-shell
[[ "$EUID" == 0 ]] || fail "Ejecuta con sudo."
[[ -x /usr/sbin/sshd ]] || fail "Falta sshd."
/usr/sbin/sshd -t || fail "sshd invalido."
systemctl is-active --quiet ssh || fail "ssh.service inactivo."
ok "OpenSSH activo y configuracion valida"
[[ "$(getent passwd "$user" | cut -d: -f6)" == /compartido ]] || fail "Home incorrecto"
[[ "$(getent passwd "$user" | cut -d: -f7)" == "$binary" ]] || fail "Shell incorrecta"
[[ "$(id -u "$user")" != 0 ]] || fail 'La cuenta restringida tiene UID 0'
id -nG "$user" | tr ' ' '\n' | grep -qx gutsnet-files || fail "No pertenece a gutsnet-files"
if id -nG "$user" | tr ' ' '\n' | grep -Eq '^(root|sudo|admin|wheel|docker|lxd|disk|shadow)$'; then fail 'Tiene grupo privilegiado'; fi
[[ -d "$jail" && "$(stat -c '%U:%G' "$jail")" == root:root ]] || fail 'Propietario jail incorrecto'
mode="$(stat -c '%a' "$jail")"
(( (8#$mode & 0022) == 0 )) || fail 'El jail es escribible por grupo/otros'
mountpoint -q "$jail/compartido" || fail 'Carpeta compartida no montada'
# Un bind mount sobre /home en particion propia aparece como
# /dev/sdaN[/ruta-relativa] en findmnt; comparar inodos, no texto SOURCE.
source_id="$(stat -Lc '%d:%i' "$shared")"
target_id="$(stat -Lc '%d:%i' "$jail/compartido")"
[[ "$source_id" == "$target_id" ]] ||
    fail "Montaje compartido inesperado (origen $source_id, destino $target_id)"
runuser -u "$user" -- test -w "$jail/compartido" \
    && runuser -u "$user" -- test -x "$jail/compartido" \
    || fail 'La cuenta no puede crear ni eliminar en /compartido'
if runuser -u "$user" -- test -w "$jail"; then fail 'La cuenta puede modificar la raiz del jail'; fi
[[ -x "$binary" && -x "$jail$binary" ]] || fail 'No existe shell restringida'
if readelf -l "$jail$binary" | grep -q INTERP; then fail 'Shell no estatica'; fi
ok 'Cuenta restringida, shell estatica, chroot y bind mount'
ok 'Escritura permitida en /compartido y raiz de la jaula protegida'
opts="$(/usr/sbin/sshd -T -C user="$user",host=localhost,addr=127.0.0.1)"
grep -qx 'chrootdirectory /home/gutsnet-jail' <<< "$opts" || fail 'ChrootDirectory incorrecto'
grep -qx 'disableforwarding yes' <<< "$opts" || fail 'Forwarding permitido'
admin="$(/usr/sbin/sshd -T -C user=guts,host=localhost,addr=127.0.0.1)"
grep -qx 'chrootdirectory none' <<< "$admin" || fail 'Admin afectado por chroot'
ok 'Match SSH solo en gutsjail, no en guts'
echo 'Pendiente: conexiones remotas y pruebas reales con SSH/SFTP.'
