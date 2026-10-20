#!/usr/bin/env bash
# GutsNet - confirmar cuatro unidades activas y puertos oficiales ocupados.
set -Eeuo pipefail
fail() { echo "ERROR: $*" >&2; exit 1; }

for name in echo_tcp_server echo_udp_server daytime_tcp_server daytime_udp_server; do
    service="gutsnet@$name.service"
    systemctl is-active --quiet "$service" || fail "$service no esta activo"
    echo "OK: $service activo"
done

tcp="$(ss -H -ltn)"
udp="$(ss -H -lun)"
[[ "$tcp" =~ :7[[:space:]] ]] || fail 'Echo TCP no escucha en el puerto 7'
[[ "$udp" =~ :7[[:space:]] ]] || fail 'Echo UDP no escucha en el puerto 7'
[[ "$tcp" =~ :13[[:space:]] ]] || fail 'Daytime TCP no escucha en el puerto 13'
[[ "$udp" =~ :13[[:space:]] ]] || fail 'Daytime UDP no escucha en el puerto 13'

echo 'OK: RFC 862 y RFC 867 escuchando en TCP/UDP 7 y 13.'
echo 'Pendiente: comprobar respuestas con los clientes y desde la red LAN.'
