# GutsNet: clientes externos y servicios Echo y Daytime

## Consultar servidores externos

Los clientes C aceptan una IP o un nombre DNS y el puerto del otro servidor.
Desde la raíz del repositorio, estos comandos compilan el cliente necesario
y realizan una consulta por Internet:

```bash
make -C C0DE/sockets echo-remoto
make -C C0DE/sockets hora-remota
```

| Consulta | Destino predeterminado | Transporte | Puerto |
| --- | --- | --- | --- |
| Echo | tcpbin.com | TCP | 4242 |
| Fecha y hora Daytime | time.nist.gov | TCP | 13 |

El primer comando envía `Hola desde GutsNet` y muestra el mensaje devuelto
por TCPbin. El segundo muestra la fecha y hora ASCII recibida de NIST.
No es necesario instalar los servidores de GutsNet para usar estos clientes.

Puedes elegir el texto y cambiar el destino sin editar el código:

```bash
make -C C0DE/sockets echo-remoto MESSAGE="Hola, soy Gustavo"
make -C C0DE/sockets echo-remoto ECHO_HOST=tcpbin.com ECHO_PORT=4242
make -C C0DE/sockets hora-remota DAYTIME_HOST=time-a-g.nist.gov DAYTIME_PORT=13
```

`ECHO_HOST` y `DAYTIME_HOST` también pueden ser la IP de otra computadora
que tenga el servicio correspondiente. Echo tiene asignado el puerto oficial
**7**, pero TCPbin ofrece su servicio público en **4242**. Si la práctica exige
el puerto 7, selecciona un servidor que lo tenga habilitado y usa `ECHO_PORT=7`.

Los comandos usan GNU `timeout`, incluido en Ubuntu, para limitar la consulta
completa a **10 segundos**, incluida la resolución DNS y la conexión.
Puedes cambiar ese límite con `SOCKET_TIMEOUT=20s`. El código 124 indica que
se alcanzó el límite; la falta de acceso a esos puertos también puede deberse
a la red desde la que se consulta. No hay sustitucion automatica por localhost.

El cliente Echo TCP compara los bytes recibidos con los enviados y termina
al completar el mensaje, aunque el otro servidor mantenga la conexión abierta.
Rechaza respuestas distintas o incompletas. Su espera de lectura/escritura
sin progreso es de 5 segundos.

### UDP y captura de tráfico

Los dos comandos anteriores usan **TCP**. Los ejecutables `echo_udp_client`
y `daytime_udp_client` también admiten un destino externo, con la sintaxis
`cliente HOST PUERTO` (y un mensaje adicional para Echo).
El servidor elegido debe ofrecer específicamente ese servicio por UDP.
NIST documenta Daytime en **TCP 13**; su servicio **UDP 123** usa NTP y requiere
otro protocolo, por lo que no se debe consultar con el cliente Daytime UDP.

Para capturar estas dos consultas publicas en Wireshark:

```text
tcp.port == 4242 || tcp.port == 13
```

Fuentes del servicio: [TCPbin](https://tcpbin.com/),
[puertos de NIST](https://www.nist.gov/pml/time-and-frequency-division/time-services/internet-time-service-firewall-information)
y [servidores de NIST](https://tf.nist.gov/tf-cgi/servers.cgi).
NIST pide no realizar consultas con una frecuencia mayor a una cada 4 segundos.

### Si la consulta externa falla

Los clientes TCP muestran en stderr la IP y el puerto de cada intento, tanto
para IPv4 como para IPv6. Si una dirección de Daytime acepta la conexión pero
cierra sin datos, el cliente intenta la siguiente dirección resuelta dentro del
límite global del comando. Si ya escribió parte de una respuesta y después falla,
termina con error para evitar mezclar datos de dos servidores.

`Connection refused` significa que la conexión fue rechazada. Ese resultado
no permite distinguir por sí solo entre un servicio cerrado y un rechazo en la red.
`Respuesta Daytime vacia` significa que la conexión terminó sin entregar datos.

Como diagnóstico puedes elegir otros destinos documentados:

```bash
make -C C0DE/sockets echo-remoto \
  ECHO_HOST=52.43.121.77 ECHO_PORT=9001 MESSAGE="Hola, soy Gustavo"

make -C C0DE/sockets hora-remota \
  DAYTIME_HOST=time-a-g.nist.gov DAYTIME_PORT=13
```

[Digi documenta Echo TCP en 52.43.121.77:9001](https://docs.digi.com/resources/documentation/digidocs/90002258/tasks/t_echo_server.htm).
NIST lista `time-a-g.nist.gov` (`129.6.15.28`) con todos sus servicios disponibles.
La disponibilidad y el acceso desde la red del usuario se comprueban al ejecutar
la consulta; estos ejemplos no suponen que la conexión ya haya sido probada allí.

### Pruebas de los clientes

```bash
make -C C0DE/sockets test
```

Compila los ocho programas y ejecuta diez pruebas con servidores temporales
en puertos libres: Echo fragmentado, conexión que permanece abierta, respuestas
incorrectas o incompletas, Daytime ASCII/vacío, UDP, cambio de destino/mensaje
y límite de espera. También comprueba que Daytime pase de una dirección sin datos
a otra que sí entrega una respuesta. Las pruebas no dependen de servicios de Internet.
El acceso a TCPbin y NIST se comprueba por separado desde la red del usuario.

## Servidores locales en los puertos oficiales

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
