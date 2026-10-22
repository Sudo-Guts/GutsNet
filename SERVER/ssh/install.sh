#!/usr/bin/env bash
# GutsNet SSH Jail con escritura limitada al area compartida.
set -Eeuo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
JAIL=/home/gutsnet-jail
SHARED=/home/gutsnet-shared/ftp/intercambio
GROUP=gutsnet-files
USER_NAME=gutsjail
SHELL_PATH=/usr/local/bin/gutsnet-shell
SSHD=/etc/ssh/sshd_config

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "[GutsNet SSH] $*"; }

preflight() {
    [[ "$EUID" == 0 ]] || die "Usa sudo."
    [[ -f "$HERE/src/gutsnet_shell.c" && -f "$HERE/sshd-match.conf" ]] || die "Archivos SSH incompletos."
    [[ -x /usr/sbin/sshd && -f "$SSHD" ]] || die "OpenSSH Server no instalado."
    command -v cc >/dev/null || die "Falta GCC."
    command -v readelf >/dev/null || die "Falta binutils."
    command -v setfacl >/dev/null || die "Falta acl. Instala con sudo apt-get install acl."
    for p in /home/gutsnet-shared /home/gutsnet-shared/ftp "$SHARED"; do
        [[ ! -L "$p" && ( ! -e "$p" || -d "$p" ) ]] || die "Ruta compartida insegura: $p"
    done
    if [[ -d "$SHARED" ]]; then
        [[ "$(stat -c '%U:%G' "$SHARED")" == "root:$GROUP" ]] \
            || die "La carpeta compartida debe pertenecer a root:$GROUP."
    fi
    [[ "$(stat -c '%U:%G' /home)" == root:root ]] || die "/home no es root:root."
    for p in "$JAIL" "$JAIL/compartido" "$JAIL/usr" "$JAIL/usr/local" "$JAIL/usr/local/bin" \
        "$JAIL/dev" "$JAIL$SHELL_PATH" "$SHELL_PATH"; do
        [[ ! -L "$p" ]] || die "Enlace simbolico prohibido: $p"
    done
    if [[ -e "$JAIL" ]]; then
        [[ -d "$JAIL" && "$(stat -c '%U:%G' "$JAIL")" == root:root ]] || die "Raiz del jail invalida."
        mode="$(stat -c '%a' "$JAIL")"
        (( (8#$mode & 0022) == 0 )) || die "Raiz del jail es escribible por grupo/otros."
    fi
    if id "$USER_NAME" >/dev/null 2>&1; then
        [[ "$(id -u "$USER_NAME")" != 0 ]] || die "La cuenta restringida no puede tener UID 0."
        [[ "$(getent passwd "$USER_NAME" | cut -d: -f6)" == /compartido ]] || die "Home de $USER_NAME inesperado."
        [[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" == "$SHELL_PATH" ]] || die "Shell de $USER_NAME inesperada."
        for dangerous in root sudo admin wheel docker lxd disk shadow; do
            if id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx "$dangerous"; then
                die "Usuario $USER_NAME pertenece a grupo $dangerous."
            fi
        done
    fi
    count="$(grep -Ec '^[[:space:]]*Subsystem[[:space:]]+sftp[[:space:]]+' "$SSHD" || true)"
    [[ "$count" == 1 ]] || die "Debe existir exactamente un Subsystem sftp activo en $SSHD."
    shopt -s nullglob
    for conf in /etc/ssh/sshd_config.d/*.conf; do
        if grep -Eq '^[[:space:]]*Subsystem[[:space:]]+sftp[[:space:]]+' "$conf"; then
            die "Hay otro Subsystem sftp en $conf; revisar manualmente."
        fi
    done
}

install_jail() {
    [[ "$EUID" == 0 ]] || die "Usa sudo."
    if ! command -v setfacl >/dev/null; then
        command -v apt-get >/dev/null || die "Falta acl (setfacl)."
        log "Instalando acl para los permisos compartidos"
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y acl
    fi
    preflight
    systemctl is-active --quiet ssh || die "ssh.service no esta activo: no modificar."
    binary="$(mktemp /tmp/gutsnet-shell.XXXXXX)"
    trap 'rm -f "$binary"' EXIT
    log "Compilando shell estatica"
    cc -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -static \
       "$HERE/src/gutsnet_shell.c" -o "$binary"
    if readelf -l "$binary" | grep -q INTERP; then
        die "El binario necesita librerias dinamicas."
    fi

    # El area puede prepararse antes de instalar FTPS; ambos usan el mismo grupo.
    getent group "$GROUP" >/dev/null || groupadd --system "$GROUP"
    for p in /home/gutsnet-shared /home/gutsnet-shared/ftp; do
        [[ -d "$p" ]] || install -d -o root -g root -m 755 "$p"
    done
    [[ -d "$SHARED" ]] || install -d -o root -g "$GROUP" -m 2770 "$SHARED"
    # Con ACL extendidas, chmod modifica la mascara, no group::. Ajustar ambos
    # evita un 2770 aparente cuyo grupo real solo conserva lectura/recorrido.
    setfacl -m u::rwx,g::rwx,m::rwx,o::--- "$SHARED"
    setfacl -m d:u::rwx,d:g::rwx,d:m::rwx,d:o::--- "$SHARED"
    chmod 2770 "$SHARED"

    install -d -o root -g root -m 755 "$JAIL" "$JAIL/usr" \
        "$JAIL/usr/local" "$JAIL/usr/local/bin" "$JAIL/dev"
    if [[ ! -e "$JAIL/compartido" ]]; then
        install -d -o root -g root -m 755 "$JAIL/compartido"
    fi
    if mountpoint -q "$JAIL/compartido"; then
        # findmnt SOURCE puede mostrar una ruta relativa al filesystem,
        # especialmente cuando /home esta en otra particion.
        # Dispositivo + inodo identifican el mismo directorio de origen.
        origin_id="$(stat -Lc '%d:%i' "$SHARED")"
        target_id="$(stat -Lc '%d:%i' "$JAIL/compartido")"
        [[ "$origin_id" == "$target_id" ]] ||
            die "Montaje existente no coincide con $SHARED"
    else
        mount --bind "$SHARED" "$JAIL/compartido"
    fi
    fstab_line="$SHARED $JAIL/compartido none bind,nofail 0 0"
    if ! grep -Fqx "$fstab_line" /etc/fstab; then
        if grep -Eq '^[^#[:space:]]+[[:space:]]+/home/gutsnet-jail/compartido[[:space:]]+' /etc/fstab; then
            die "Existe un montaje diferente en /etc/fstab."
        fi
        cp -a /etc/fstab "/etc/fstab.gutsnet-backup-$(date +%Y%m%d-%H%M%S)-$$"
        printf '\n%s\n' "$fstab_line" >> /etc/fstab
    fi
    for item in 'null 1 3' 'zero 1 5' 'tty 5 0' 'urandom 1 9'; do
        read -r name major minor <<< "$item"
        [[ ! -L "$JAIL/dev/$name" ]] || die "Dispositivo inseguro: $name"
        if [[ ! -e "$JAIL/dev/$name" ]]; then
            mknod -m 666 "$JAIL/dev/$name" c "$major" "$minor"
        fi
    done

    install -o root -g root -m 755 "$binary" "$SHELL_PATH"
    install -o root -g root -m 755 "$binary" "$JAIL$SHELL_PATH"
    grep -Fqx "$SHELL_PATH" /etc/shells || printf '%s\n' "$SHELL_PATH" >> /etc/shells
    if ! id "$USER_NAME" >/dev/null 2>&1; then
        useradd --no-create-home --home-dir /compartido \
            --shell "$SHELL_PATH" --user-group --groups "$GROUP" "$USER_NAME"
    else
        usermod -a -G "$GROUP" "$USER_NAME"
    fi
    if ! runuser -u "$USER_NAME" -- test -w "$JAIL/compartido" \
        || ! runuser -u "$USER_NAME" -- test -x "$JAIL/compartido"; then
        runuser -u "$USER_NAME" -- id >&2
        stat -c '%A %U:%G %n' /home /home/gutsnet-shared /home/gutsnet-shared/ftp \
            "$SHARED" "$JAIL" "$JAIL/compartido" >&2
        die "La cuenta restringida no puede escribir/recorrer el area compartida."
    fi

    # Respaldar antes de tocar OpenSSH. Nunca reiniciar una sesion sin validar.
    backup="$SSHD.gutsnet-backup-$(date +%Y%m%d-%H%M%S)-$$"
    cp -a "$SSHD" "$backup"
    temp="$(mktemp /etc/ssh/sshd_config.gutsnet.XXXXXX)"
    awk '/^[[:space:]]*Subsystem[[:space:]]+sftp[[:space:]]+/ {
        print "Subsystem sftp internal-sftp"; next
    } { print }' "$SSHD" > "$temp"
    if ! grep -Fq '# BEGIN GUTSNET JAIL' "$temp"; then
        printf '\n' >> "$temp"
        cat "$HERE/sshd-match.conf" >> "$temp"
    fi
    chown root:root "$temp"
    chmod 644 "$temp"
    mv -f "$temp" "$SSHD"

    valid=yes
    /usr/sbin/sshd -t -f "$SSHD" || valid=no
    if [[ "$valid" == yes ]]; then
        jail_opts="$(/usr/sbin/sshd -T -C user="$USER_NAME",host=localhost,addr=127.0.0.1)" || valid=no
        admin_opts="$(/usr/sbin/sshd -T -C user=guts,host=localhost,addr=127.0.0.1)" || valid=no
    fi
    if [[ "$valid" == yes ]]; then
        grep -qx 'chrootdirectory /home/gutsnet-jail' <<< "$jail_opts" || valid=no
        grep -qx 'disableforwarding yes' <<< "$jail_opts" || valid=no
        grep -qx 'chrootdirectory none' <<< "$admin_opts" || valid=no
    fi
    if [[ "$valid" != yes ]]; then
        cp -a "$backup" "$SSHD"
        die "Validacion SSH fallida; configuracion restaurada: $backup"
    fi
    if ! systemctl reload ssh; then
        cp -a "$backup" "$SSHD"
        die "Recarga fallida: archivo SSH restaurado."
    fi
    log "SSH validado. Conserva abierta la sesion administrativa actual."
    log "Ahora ejecuta: sudo passwd $USER_NAME"
    log "Despues: sudo bash SERVER/ssh/check.sh"
}

if [[ "$#" != 1 ]]; then
    echo "Uso: sudo bash SERVER/ssh/install.sh --check|--install"
    exit 2
fi
case "$1" in
    --check) preflight; log "OK: requisitos listos; sin cambios." ;;
    --install) install_jail ;;
    *) echo "Uso: sudo bash SERVER/ssh/install.sh --check|--install"; exit 2 ;;
esac
