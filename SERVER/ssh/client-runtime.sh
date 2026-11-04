#!/usr/bin/env bash
# Funciones del instalador para el cliente SSH dentro del chroot.

# Crea solo directorios root:root y rechaza enlaces en toda la ruta de destino.
client_directory() {
    local relative="$2" current="$1" component
    local -a components
    IFS=/ read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        [[ -n "$component" ]] || continue
        [[ "$component" != . && "$component" != .. ]] || return 1
        current="$current/$component"
        [[ ! -L "$current" && ( ! -e "$current" || -d "$current" ) ]] || return 1
        install -d -o root -g root -m 755 "$current" || return 1
    done
}

# Copia binarios/librerias del sistema; nunca incluye una shell de proposito general.
client_file() {
    local jail="$1" source="$2" target="$3" mode="$4"
    client_directory "$jail" "$(dirname -- "$target")" || return 1
    [[ ! -L "$jail$target" && ( ! -e "$jail$target" || -f "$jail$target" ) ]] || return 1
    install -o root -g root -m "$mode" "$source" "$jail$target"
}

install_ssh_client() {
    local jail="$1" user="$2" here="$3" dependencies library entry uid gid
    [[ "$EUID" == 0 && -d "$jail" && ! -L "$jail" ]] || return 1
    dependencies="$(LC_ALL=C ldd /usr/bin/ssh)" || return 1
    [[ "$dependencies" != *'not found'* ]] || return 1
    client_file "$jail" /usr/bin/ssh /usr/bin/ssh 755 || return 1
    while IFS= read -r library; do
        [[ -f "$library" ]] || return 1
        client_file "$jail" "$library" "$library" 755 || return 1
    done < <(awk '$2 == "=>" && $3 ~ /^\// {print $3} $1 ~ /^\// {print $1}' <<< "$dependencies" | sort -u)
    # glibc reciente integra files/dns; copiar tambien los modulos si existen.
    for library in /lib/*-linux-gnu/libnss_files.so.2 /lib/*-linux-gnu/libnss_dns.so.2; do
        [[ ! -f "$library" ]] || client_file "$jail" "$library" "$library" 755 || return 1
    done
    client_file "$jail" "$here/ssh-client.conf" /etc/gutsnet/ssh_config 644 || return 1
    for entry in hosts resolv.conf; do
        client_file "$jail" "/etc/$entry" "/etc/$entry" 644 || return 1
    done
    for entry in passwd group nsswitch.conf; do
        [[ ! -L "$jail/etc/$entry" && ( ! -e "$jail/etc/$entry" || -f "$jail/etc/$entry" ) ]] || return 1
        install -o root -g root -m 644 /dev/null "$jail/etc/$entry" || return 1
    done
    uid="$(id -u "$user")" || return 1
    gid="$(id -g "$user")" || return 1
    printf '%s:x:%s:%s:GutsNet SSH:/var/lib/gutsnet-ssh:/usr/local/bin/gutsnet-shell\n' "$user" "$uid" "$gid" > "$jail/etc/passwd"
    printf '%s:x:%s:\n' "$user" "$gid" > "$jail/etc/group"
    printf 'passwd: files\ngroup: files\nhosts: files dns\n' > "$jail/etc/nsswitch.conf"
    client_directory "$jail" /var/lib || return 1
    [[ ! -L "$jail/var/lib/gutsnet-ssh" && ( ! -e "$jail/var/lib/gutsnet-ssh" || -d "$jail/var/lib/gutsnet-ssh" ) ]] || return 1
    # Bloquear el directorio mientras root revisa/crea el archivo de claves.
    install -d -o root -g root -m 700 "$jail/var/lib/gutsnet-ssh" || return 1
    # Conservar claves aceptadas; no seguir enlaces creados mediante SFTP.
    entry="$jail/var/lib/gutsnet-ssh/known_hosts"
    [[ ! -L "$entry" && ( ! -e "$entry" || -f "$entry" ) ]] || return 1
    if [[ ! -e "$entry" ]]; then
        install -o "$uid" -g "$gid" -m 600 /dev/null "$entry" || return 1
    fi
    [[ "$(stat -c '%u:%g:%a:%h' "$entry")" == "$uid:$gid:600:1" ]] || return 1
    chown "$uid:$gid" "$jail/var/lib/gutsnet-ssh" || return 1
    chroot --userspec="$uid:$gid" "$jail" /usr/bin/ssh -G -F /etc/gutsnet/ssh_config -T -l "$user" localhost >/dev/null
}
