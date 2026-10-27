#!/usr/bin/env bash
# vsftpd entra primero al home de passwd antes de aplicar local_root.
# /compartido es el home de gutsjail dentro de SSH; en el host solo se necesita
# un directorio vacio de entrada. La biblioteca sigue fuera de esta ruta.

check_ftps_login_home() {
    local path=/compartido
    [[ ! -L "$path" ]] || { echo 'ERROR: /compartido del host no puede ser un enlace' >&2; return 1; }
    [[ -e "$path" ]] || return 0
    [[ -d "$path" && "$(stat -c '%U:%G:%a' "$path")" == root:root:755 ]] || {
        echo 'ERROR: /compartido del host debe ser un directorio root:root 755 vacio' >&2; return 1;
    }
    [[ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit)" ]] || {
        echo 'ERROR: /compartido del host contiene archivos ajenos; no se modificara' >&2; return 1;
    }
}

prepare_ftps_login_home() {
    [[ "$EUID" == 0 ]] || { echo 'ERROR: prepara FTPS con sudo' >&2; return 1; }
    check_ftps_login_home || return 1
    [[ -d /compartido ]] || install -d -o root -g root -m 755 /compartido
}
