#!/usr/bin/env bash
# Unifica Cinema, SSH Jail/SFTP y FTPS mediante una ejecucion explicita.
set -Eeuo pipefail
umask 077
media=/home/gutsnet-shared/peliculas
old=/home/gutsnet-shared/ftp/intercambio
jail=/home/gutsnet-jail/compartido
stage=/home/gutsnet-shared/.cinema-incoming
oldstage="$media/.incoming"
auth=/etc/gutsnet/cinema.htpasswd
allow=/etc/vsftpd.gutsnet-users
marker=/etc/gutsnet/media-unificada

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[GutsNet Media] $*"; }
same() {
    [[ -d "$1" && -d "$2" ]] &&
        [[ "$(stat -Lc '%d:%i' "$1")" == "$(stat -Lc '%d:%i' "$2")" ]]
}
preflight() {
    [[ $EUID == 0 ]] || die 'Ejecuta con sudo'
    for cmd in rsync mount umount mountpoint setfacl getfacl flock; do
        command -v "$cmd" >/dev/null || die "Falta $cmd"
    done
    for path in "$media" "$old" "$jail"; do
        [[ -d "$path" && ! -L "$path" ]] || die "Ruta no valida: $path"
    done
    [[ -f "$auth" && -f "$allow" ]] || die 'Faltan credenciales actuales'
    id gutsjail >/dev/null || die 'Falta gutsjail'
    id -nG gutsjail | tr ' ' '\n' | grep -qx gutsnet-files || die 'Falta grupo gutsnet-files'
    [[ ! -L "$stage" && ! -L "$oldstage" ]] || die 'Staging no puede ser symlink'
    [[ ! -e "$stage" || ! -e "$oldstage" ]] || die 'Hay dos directorios staging, revisar manualmente'
    if ! same "$media" "$old"; then
        if find "$old" -mindepth 1 ! -type d ! -type f -print -quit | grep -q .; then
            die 'Archivos especiales o symlinks en FTP: revisar primero'
        fi
        while IFS= read -r -d '' entry; do
            rel="$(realpath --relative-to="$old" "$entry")"
            [[ ! -e "$media/$rel" && ! -L "$media/$rel" ]] ||
                die "Colision de nombres: $rel"
        done < <(find "$old" -mindepth 1 -print0)
    fi
    if mountpoint -q "$jail" && ! same "$jail" "$old" && ! same "$jail" "$media"; then
        die 'Montaje SSH desconocido'
    fi
    if mountpoint -q "$old" && ! same "$old" "$media"; then
        die 'Montaje FTP desconocido'
    fi
    awk -v j="$jail" -v o="$old" -v m="$media" '
      /^[[:space:]]*#/ || NF < 2 {next}
      $2 == j && $1 != o && $1 != m {bad=1}
      $2 == o && $1 != m {bad=1}
      END {exit bad?1:0}
    ' /etc/fstab || die 'fstab contiene un montaje ajeno'
}
[[ $# == 1 && ( $1 == --check || $1 == --apply ) ]] ||
    die 'Uso: sudo bash SERVER/shared/unify.sh --check|--apply'
preflight
if [[ $1 == --check ]]; then
    log "Cinema: $media"
    log "FTPS: $old"
    log "SSH: $jail"
    same "$media" "$old" && same "$media" "$jail" &&
        log 'YA UNIFICADOS' || log 'Aun separados: sera necesaria la migracion'
    log 'Sin cambios'
    exit 0
fi

# La migracion comprueba la cuenta; las pruebas HTTPS verifican su contrasena.
# No pedir una credencial con el prompt oculto al redirigir stderr.
grep -q '^gutsjail:' "$auth" ||
    die "Primero ejecuta: sudo htpasswd -B $auth gutsjail"
exec 9>/run/lock/gutsnet-media.lock
flock -n 9 || die 'Ya hay una migracion en curso'
preflight
if [[ -f "$marker" ]] && same "$media" "$old" && same "$media" "$jail"; then
    bash "$(dirname "$0")/check.sh"
    log 'Biblioteca ya unificada; sin cambios'
    exit 0
fi
if pgrep -u gutsjail >/dev/null 2>&1; then
    die 'Cierra las sesiones SSH/SFTP de gutsjail antes de migrar'
fi
if id gutsftp >/dev/null 2>&1 && pgrep -u gutsftp >/dev/null 2>&1; then
    die 'Cierra las sesiones FTPS de gutsftp antes de migrar'
fi
was_apache=0
was_ftp=0
resume() {
    ((was_ftp == 0)) || systemctl start vsftpd || true
    ((was_apache == 0)) || systemctl start apache2 || true
}
trap resume EXIT
if systemctl is-active --quiet apache2; then was_apache=1; systemctl stop apache2; fi
if systemctl is-active --quiet vsftpd; then was_ftp=1; systemctl stop vsftpd; fi
preflight

if ! same "$media" "$old"; then
    log 'Copiando archivos FTP existentes, sin sobrescribir Cinema...'
    rsync -a -- "$old/" "$media/"
    [[ -z "$(rsync -rcn --out-format='%n' -- "$old/" "$media/")" ]] ||
        die 'La copia no se verifico; se mantienen los montajes antiguos'
fi
if [[ -d "$oldstage" ]]; then
    mv -- "$oldstage" "$stage"
fi
install -d -o www-data -g www-data -m 700 "$stage"
setfacl -b -k "$stage"
chown www-data:www-data "$stage"
chmod 0700 "$stage"

# Directorio comun del grupo; staging permanece fuera.
chown root:gutsnet-files "$media"
chmod 2770 "$media"
setfacl -m u:www-data:rwx,g:gutsnet-files:rwx,m::rwx,o::--- "$media"
setfacl -m d:u:www-data:rwx,d:g:gutsnet-files:rwx,d:m::rwx,d:o::--- "$media"
find "$media" -mindepth 1 -type d -exec chgrp gutsnet-files {} + -exec chmod g+s {} + -exec setfacl -m u:www-data:rwx,g:gutsnet-files:rwx,m::rwx,d:u:www-data:rwx,d:g:gutsnet-files:rwx,d:m::rwx,d:o::--- {} +
find "$media" -mindepth 1 -type f -exec setfacl -m u:www-data:rw-,g:gutsnet-files:rw-,m::rw- {} +
usermod -a -G gutsnet-files www-data

stamp="$(date +%Y%m%d-%H%M%S)-$$"
backup=/home/gutsnet-shared/.gutsnet-backups
install -d -o root -g root -m 700 "$backup"
if mountpoint -q "$jail" && ! same "$media" "$jail"; then
    umount "$jail" || die 'El jail esta ocupado'
fi
if ! same "$media" "$old"; then
    mv -- "$old" "$backup/intercambio-$stamp"
    chmod 0700 "$backup/intercambio-$stamp"
    install -d -o root -g root -m 755 "$old"
    mount --bind "$media" "$old"
fi
if ! mountpoint -q "$jail"; then
    mount --bind "$media" "$jail"
fi
same "$media" "$old" && same "$media" "$jail" || die 'Los montajes no coinciden'

cp -a /etc/fstab "/etc/fstab.gutsnet-backup-$stamp"
tmp="$(mktemp /etc/fstab.gutsnet.XXXXXXXX)"
awk -v j="$jail" -v o="$old" '
  /^[[:space:]]*#/ {print;next}
  NF >= 2 && ($2 == j || $2 == o) {next}
  {print}
' /etc/fstab > "$tmp"
printf '%s %s none bind,nofail 0 0\n' "$media" "$old" >> "$tmp"
printf '%s %s none bind,nofail 0 0\n' "$media" "$jail" >> "$tmp"
chown root:root "$tmp"
chmod 644 "$tmp"
mv "$tmp" /etc/fstab
systemctl daemon-reload

cp -a "$allow" "$allow.gutsnet-backup-$stamp"
printf '%s\n' gutsjail > "$allow"
chown root:root "$allow"
chmod 600 "$allow"
install -o root -g root -m 600 /dev/null "$marker"
log "Respaldo de intercambio anterior: $backup/intercambio-$stamp (si existia)"
log "Respaldo de fstab: /etc/fstab.gutsnet-backup-$stamp"
log 'Ahora instala la nueva version de Cinema antes de usar la web: make install-cinema'
log 'No bloquees cuentas antiguas hasta verificar SSH, FTPS y Cinema.'
