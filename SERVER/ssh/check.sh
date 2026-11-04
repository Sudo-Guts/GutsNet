#!/usr/bin/env bash
# GutsNet - local SSH Jail verification (read-only).
set -Eeuo pipefail
fail() { echo "ERROR: $*" >&2; exit 1; }
ok() { echo "OK: $*"; }
user=gutsjail
jail=/home/gutsnet-jail
shared=/home/gutsnet-shared/ftp/intercambio
[[ ! -f /etc/gutsnet/media-unificada ]] || shared=/home/gutsnet-shared/peliculas
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
# Bash respeta ACL y grupos suplementarios, a diferencia de test en uutils 0.10.
runuser -u "$user" -- /bin/bash -p -c 'builtin test "$@"' -- -w "$jail/compartido" \
    && runuser -u "$user" -- /bin/bash -p -c 'builtin test "$@"' -- -x "$jail/compartido" \
    || fail 'La cuenta no puede crear ni eliminar en /compartido'
if runuser -u "$user" -- /bin/bash -p -c 'builtin test "$@"' -- -w "$jail"; then fail 'La cuenta puede modificar la raiz del jail'; fi
[[ -x "$binary" && -x "$jail$binary" ]] || fail 'No existe shell restringida'
if readelf -l "$jail$binary" | grep -q INTERP; then fail 'Shell no estatica'; fi
ok 'Cuenta restringida, shell estatica, chroot y bind mount'
ok 'Escritura permitida en /compartido y raiz de la jaula protegida'
[[ -x "$jail/usr/bin/ssh" && ! -L "$jail/usr/bin/ssh" ]] || fail 'Falta cliente SSH saliente'
for device in null zero tty urandom; do
    [[ -c "$jail/dev/$device" && ! -L "$jail/dev/$device" && "$(stat -c '%U:%G:%a' "$jail/dev/$device")" == root:root:666 ]] || fail "Dispositivo SSH incorrecto: $device"
done
for path in /usr /usr/bin /usr/bin/ssh /etc /etc/gutsnet /etc/gutsnet/ssh_config /etc/passwd /etc/group /etc/nsswitch.conf /etc/hosts /etc/resolv.conf /var /var/lib; do
    [[ ! -L "$jail$path" && "$(stat -c '%U:%G' "$jail$path")" == root:root ]] || fail "Ruta de cliente insegura: $path"
    mode="$(stat -c '%a' "$jail$path")"
    (( (8#$mode & 0022) == 0 )) || fail "Ruta de cliente escribible: $path"
done
[[ "$(stat -c '%u:%g:%a' "$jail/var/lib/gutsnet-ssh")" == "$(id -u "$user"):$(id -g "$user"):700" ]] || fail 'Directorio de claves incorrecto'
[[ ! -L "$jail/var/lib/gutsnet-ssh/known_hosts" && "$(stat -c '%u:%g:%a:%h' "$jail/var/lib/gutsnet-ssh/known_hosts")" == "$(id -u "$user"):$(id -g "$user"):600:1" ]] || fail 'known_hosts incorrecto'
client_opts="$(chroot --userspec="$(id -u "$user"):$(id -g "$user")" "$jail" /usr/bin/ssh -G -F /etc/gutsnet/ssh_config -T -l "$user" localhost)" || fail 'Cliente SSH no ejecutable dentro del chroot'
for option in 'escapechar none' 'enableescapecommandline no' 'permitlocalcommand no' 'clearallforwardings yes' 'forwardagent no' 'forwardx11 no' 'identityagent none' 'stricthostkeychecking ask' 'globalknownhostsfile /dev/null' 'userknownhostsfile /var/lib/gutsnet-ssh/known_hosts'; do
    grep -Fqx "$option" <<< "$client_opts" || fail "Opcion saliente incorrecta: $option"
done
grep -Eq '^pubkeyauthentication (no|false)$' <<< "$client_opts" || fail 'Autenticacion por llaves habilitada en el cliente'
if grep -Eq '^(proxycommand|proxyjump|controlpath) ' <<< "$client_opts"; then fail 'Proxy o multiplexacion habilitados'; fi
ok 'Cliente SSH saliente listo y claves conocidas privadas'
opts="$(/usr/sbin/sshd -T -C user="$user",host=localhost,addr=127.0.0.1)"
grep -qx 'chrootdirectory /home/gutsnet-jail' <<< "$opts" || fail 'ChrootDirectory incorrecto'
grep -qx 'disableforwarding yes' <<< "$opts" || fail 'Forwarding permitido'
admin="$(/usr/sbin/sshd -T -C user=guts,host=localhost,addr=127.0.0.1)"
grep -qx 'chrootdirectory none' <<< "$admin" || fail 'Admin afectado por chroot'
ok 'Match SSH solo en gutsjail, no en guts'
echo 'Pendiente: conexiones remotas, SSH/SFTP y salto con ssh usuario@otro-servidor.'
