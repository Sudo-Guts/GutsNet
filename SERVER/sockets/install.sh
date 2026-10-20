#!/usr/bin/env bash
# GutsNet - servidores TCP/UDP en los puertos 7 y 13.
# --check no cambia el sistema; --install instala unidades systemd.
set -Eeuo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
src="$repo/C0DE/sockets"
dest=/usr/local/libexec/gutsnet
unit=/etc/systemd/system/gutsnet@.service
template="$here/gutsnet@.service"

fail() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "[GutsNet sockets] $*"; }

preflight() {
    [[ -f "$template" ]] || fail "Falta unidad $template"
    command -v gcc >/dev/null || fail 'Falta gcc'
    command -v ss >/dev/null || fail 'Falta ss'
    command -v systemctl >/dev/null || fail 'Falta systemctl'
    getent passwd nobody >/dev/null || fail 'No existe nobody'
    getent group nogroup >/dev/null || fail 'No existe nogroup'
    [[ ! -L "$dest" && ! -L "$unit" ]] || fail 'Directorio o unidad es symlink'
    for name in echo_tcp_server echo_udp_server; do
        [[ -f "$src/src/echo/$name.c" ]] || fail "Falta $name.c"
    done
    for name in daytime_tcp_server daytime_udp_server; do
        [[ -f "$src/src/daytime/$name.c" ]] || fail "Falta $name.c"
    done
    [[ -f "$src/src/daytime/daytime_format.c" ]] || fail 'Falta daytime_format.c'
    [[ -f "$src/inc/daytime.h" ]] || fail 'Falta daytime.h'
}

ports() {
    info 'Puertos actualmente ocupados (TCP/UDP 7 y 13):'
    { ss -H -ltn; ss -H -lun; } | awk '$4 ~ /:(7|13)$/ { print }' || true
}

do_install() {
    [[ "$EUID" -eq 0 ]] || fail 'Ejecuta con sudo'
    preflight
    ports
    temp="$(mktemp -d /tmp/gutsnet-sockets.XXXXXXXX)"
    trap 'rm -rf "$temp"' EXIT

    info 'Compilando servidores...'
    for name in echo_tcp_server echo_udp_server; do
        gcc -std=c11 -O2 -Wall -Wextra -Wpedantic \
          "$src/src/echo/$name.c" -o "$temp/$name"
    done
    for name in daytime_tcp_server daytime_udp_server; do
        gcc -std=c11 -O2 -Wall -Wextra -Wpedantic -I"$src/inc" \
          "$src/src/daytime/$name.c" \
          "$src/src/daytime/daytime_format.c" -o "$temp/$name"
    done

    install -d -o root -g root -m 755 "$dest"
    for name in echo_tcp_server echo_udp_server daytime_tcp_server daytime_udp_server; do
        if [[ -e "$dest/$name" ]]; then
            cp -a "$dest/$name" "$dest/$name.gutsnet-backup-$(date +%Y%m%d-%H%M%S)-$$"
        fi
        install -o root -g root -m 755 "$temp/$name" "$dest/$name"
    done
    if [[ -e "$unit" ]]; then
        cp -a "$unit" "$unit.gutsnet-backup-$(date +%Y%m%d-%H%M%S)-$$"
    fi
    install -o root -g root -m 644 "$template" "$unit"
    systemctl daemon-reload
    info 'Iniciando servicios en los puertos oficiales...'
    systemctl enable --now \
      gutsnet@echo_tcp_server.service \
      gutsnet@echo_udp_server.service \
      gutsnet@daytime_tcp_server.service \
      gutsnet@daytime_udp_server.service || {
        systemctl --no-pager status 'gutsnet@*' || true
        fail 'Uno o mas servidores no arrancaron. Revisa journalctl.'
      }
    info 'Servicios instalados. Ejecuta: sudo bash SERVER/sockets/check.sh'
}

if [[ "$#" -ne 1 ]]; then
    echo 'Uso: sudo bash SERVER/sockets/install.sh --check|--install'
    exit 2
fi
case "$1" in
    --check) preflight; ports; info 'Comprobaciones correctas; sin cambios.' ;;
    --install) do_install ;;
    *) fail 'Argumento no valido. Usa --check o --install' ;;
esac
