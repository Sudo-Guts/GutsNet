#!/usr/bin/env bash
# Verificacion local de biblioteca unificada (solo lectura).
set -Eeuo pipefail
[[ "$EUID" == 0 ]] || { echo "Ejecuta con sudo" >&2; exit 1; }
media=/home/gutsnet-shared/peliculas
ftp=/home/gutsnet-shared/ftp/intercambio
ssh=/home/gutsnet-jail/compartido
stage=/home/gutsnet-shared/.cinema-incoming
[[ -f /etc/gutsnet/media-unificada ]] || { echo 'Migracion no aplicada'; exit 1; }
mountpoint -q "$ftp" && mountpoint -q "$ssh" || { echo 'Falta bind mount'; exit 1; }
ref="$(stat -Lc '%d:%i' "$media")"
for path in "$ftp" "$ssh"; do
    [[ -d "$path" && ! -L "$path" && "$(stat -Lc '%d:%i' "$path")" == "$ref" ]] ||
        { echo "No coincide $path"; exit 1; }
done
[[ -d "$stage" && ! -L "$stage" && "$(stat -c '%U:%G' "$stage")" == www-data:www-data ]] ||
    { echo 'Staging no es privado'; exit 1; }
[[ "$(stat -c '%a' "$stage")" == 700 ]] || { echo 'Staging requiere permisos 700'; exit 1; }
# Bash respeta ACL y grupos suplementarios, a diferencia de test en uutils 0.10.
if runuser -u gutsjail -- /bin/bash -p -c 'builtin test "$@"' -- -x "$stage"; then
    echo 'Staging accesible para gutsjail'; exit 1
fi
[[ ! -e "$media/.incoming" ]] || { echo 'Staging antiguo en la biblioteca'; exit 1; }
for user in gutsjail www-data; do
    id -nG "$user" | tr ' ' '\n' | grep -qx gutsnet-files ||
        { echo "Falta grupo: $user"; exit 1; }
done
runuser -u gutsjail -- /bin/bash -p -c 'builtin test "$@"' -- -w "$ssh" || { echo 'Jail sin escritura'; exit 1; }
runuser -u www-data -- /bin/bash -p -c 'builtin test "$@"' -- -w "$media" || { echo 'Apache sin escritura'; exit 1; }
grep -qx gutsjail /etc/vsftpd.gutsnet-users || { echo 'FTPS sin gutsjail'; exit 1; }
[[ "$(sed '/^[[:space:]]*$/d' /etc/vsftpd.gutsnet-users)" == gutsjail ]] || { echo 'FTPS permite otras cuentas'; exit 1; }
echo 'OK: Cinema, SFTP y FTPS son una biblioteca real'
echo 'OK: staging privado y ACL de escritura para gutsjail/www-data'
echo 'Pendiente: pruebas funcionales autenticadas desde navegador y clientes'
