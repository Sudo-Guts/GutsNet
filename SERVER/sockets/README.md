# GutsNet — servicios Echo y Daytime en sus puertos oficiales

La implementación de Echo (RFC 862) y Daytime (RFC 867) está en
C0DE/sockets. Este módulo instala los cuatro SERVIDORES (TCP y UDP) como
unidades systemd en los puertos predeterminados:

| Programa | Transporte | Puerto |
| --- | --- | --- |
| echo_tcp_server | TCP | 7 |
| echo_udp_server | UDP | 7 |
| daytime_tcp_server | TCP | 13 |
| daytime_udp_server | UDP | 13 |

Systemd ejecuta los binarios como nobody:nogroup y solo concede la
capacidad CAP_NET_BIND_SERVICE, sin ejecutar los servidores como root.
Los binarios se instalan en /usr/local/libexec/gutsnet/ con propiedad
root:root; no se ejecutan desde el repositorio editable por guts.

## Instalación en Ubuntu Server

Desde la raíz de GutsNet:

    cd ~/GutsNet
    git pull --ff-only origin main

    sudo bash SERVER/sockets/install.sh --check
    sudo bash SERVER/sockets/install.sh --install
    sudo bash SERVER/sockets/check.sh

Si la revisión previa muestra puertos ocupados por procesos ajenos,
identificarlos antes de ejecutar el instalador. El instalador no cambia
Apache, FTP, SSH, Cinema ni el firewall. Las unidades anteriores se
respaldan si existen. Cada unidad se habilita para iniciarse al arrancar.

## Comprobación funcional en el propio servidor

    make -C C0DE/sockets
    C0DE/sockets/out/echo_tcp_client 127.0.0.1 7 "Hola TCP"
    C0DE/sockets/out/echo_udp_client 127.0.0.1 7 "Hola UDP"
    C0DE/sockets/out/daytime_tcp_client 127.0.0.1 13
    C0DE/sockets/out/daytime_udp_client 127.0.0.1 13

Repite las llamadas con la IP real del servidor desde otra computadora.
Para Wireshark, captura en la interfaz LAN y aplica este filtro:

    tcp.port == 7 || udp.port == 7 || tcp.port == 13 || udp.port == 13

TCP debe mostrar establecimiento de conexión y datos. UDP muestra
datagramas sin establecimiento de conexión.

## Diagnóstico

    sudo systemctl status 'gutsnet@*' --no-pager
    sudo journalctl -u gutsnet@echo_tcp_server -n 30 --no-pager
    sudo ss -ltnup

Desactivar sin borrar ni afectar otros servicios:

    sudo systemctl disable --now \
      gutsnet@echo_tcp_server.service gutsnet@echo_udp_server.service \
      gutsnet@daytime_tcp_server.service gutsnet@daytime_udp_server.service

No exponer puertos 7 y 13 a Internet fuera de la LAN del laboratorio.
