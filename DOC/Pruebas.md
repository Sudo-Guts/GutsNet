# Pruebas y evidencias de GutsNet

Estas pruebas se realizan contra Apache **ya desplegado**. La existencia de
los archivos en GitHub no demuestra que el servidor los esté entregando.

## Requisitos

- Ubuntu con Apache y PHP (extensión PDO SQLite habilitada).
- Herramientas de línea de comandos: `curl`, `php-cli` y `make`.
- Acceso al directorio `~/GutsNet`.
- Sitio configurado con el VirtualHost `gutsnet.test`.
- Base de datos en `/var/lib/gutsnet/visitas.sqlite`, con permisos para Apache.

## 1. Comprobaciones de sintaxis

Desde la raíz del repositorio:

```bash
php -l C0DE/web/public/api/visitas.php
node --check C0DE/web/public/assets/js/main.js
sudo apache2ctl configtest
```

Las comprobaciones deben terminar sin errores. `node` es opcional en el
servidor de producción, pero útil para validar JavaScript.

Sin iniciar Apache se puede revisar el portafolio:

```bash
python3 scripts/check-web.py
python3 scripts/version-web-assets.py --check
node scripts/test-web-ui.cjs
```

Estas comprobaciones verifican enlaces, fragmentos, recursos, IDs, versiones y
referencias de accesibilidad. Las pruebas de JavaScript cubren la señal sintética,
filtros, menú responsive, contador y reproductor con APIs DOM mínimas. No abren
un navegador ni prueban la salida de audio, el video o el diseño renderizado.

Después de editar CSS, JavaScript o las ilustraciones SVG, ejecuta
`python3 scripts/version-web-assets.py`. El script añade a cada URL una versión
calculada a partir del contenido del archivo. Así el navegador solicita el
recurso nuevo cuando cambia su contenido. Las versiones se guardan en Git.

## 2. Publicación

```bash
make preview
make deploy
make test
```

`make preview` permite revisar las modificaciones antes de copiar archivos.
`make test` comprueba que la página inicial devuelve HTTP 200.

**Advertencia:** `make deploy` emplea `rsync --delete`: el directorio publicado
`/var/www/gutsnet/public` no debe contener bases de datos, películas privadas
ni archivos que no estén dentro de `C0DE/web/public`.

## 3. Prueba integral HTTP

Desde el servidor:

```bash
make test-web
```

Este objetivo ejecuta `scripts/test-web.sh` y verifica:

| Recurso | Resultado esperado |
| --- | --- |
| Inicio y materias | HTTP 200 y `text/html` |
| Hoja de estilos | HTTP 200 y `text/css` |
| JavaScript | HTTP 200 y tipo de contenido JavaScript |
| HTML, CSS y JavaScript publicados | Coinciden con la copia local de la rama |
| URL de CSS y JavaScript en el HTML | Incluyen la versión actual de cada recurso |
| Dos pistas MP3 | HTTP 200 y `audio/mpeg` |
| Video MP4 | HTTP 206 al solicitar un rango y `video/mp4` |
| Contador GET | HTTP 405 |
| Contador POST | HTTP 200 con JSON que contiene `visitas` |
| Segundo POST | Número de visitas mayor que el anterior |

**Importante:** esta prueba incrementa el contador **dos veces**.
Si hay otros visitantes simultáneos, la diferencia podría superar dos,
pero los dos valores obtenidos deben ser crecientes.

Desde otra computadora, con acceso a la red del servidor:

```bash
GUTSNET_URL=http://192.168.244.135 GUTSNET_HOST=gutsnet.test make test-web
```

La dirección IP debe actualizarse cuando cambie. Para ejecutar desde otro
equipo se requiere una copia del repositorio con el script y `php-cli`,
`curl` y `make` instalados.

## 4. Verificar los códecs del video

La extensión MP4 y el tipo MIME por sí solos no garantizan la reproducción
en todos los navegadores. Para revisar los códecs:

```bash
ffprobe -v error \
    -show_entries format=format_name,duration \
    -show_entries stream=codec_type,codec_name \
    -of default=noprint_wrappers=1 \
    C0DE/web/public/assets/video/demostracion.mp4
```

`ffprobe` pertenece al paquete `ffmpeg`. Para una buena compatibilidad
en navegadores, conviene utilizar video H.264 y audio AAC, cuando exista
audio. Después abre la página y prueba **reproducir, pausar y desplazarte**
por el video.

## 5. Pruebas manuales en el navegador

1. Abrir la página desde el servidor y desde la computadora administradora.
2. Verificar diseño en escritorio y móvil.
3. Reproducir, pausar y cambiar las dos pistas de audio.
4. Recargar la página y comprobar que aumente el contador.
5. Reproducir el video e intentar desplazarse por la línea de tiempo.
6. Abrir los enlaces a materias y proyectos.
7. Comprobar en la consola del navegador que no existan errores 404 ni errores de JavaScript.
8. Cambiar frecuencia y amplitud en la portada; la gráfica debe corresponder a
   una ventana de un segundo, sin superar la pantalla al ajustar la amplitud.
9. Probar los cuatro filtros y volver a «Todo el taller»; deben reaparecer los
   seis proyectos. Recorrer los botones con teclado y comprobar el foco visible.
10. En móvil, abrir y cerrar el menú, seguir un enlace y cerrar con Escape.
    Al pasar a escritorio la navegación debe permanecer visible.
11. Desactivar JavaScript: proyectos, materias, video y enlaces siguen visibles;
    los filtros se ocultan y los controles de la señal quedan deshabilitados.
12. Reproducir música y luego el video: la música debe pausarse.

El CV definitivo sigue pendiente. Cinema ya cuenta con instalación y pruebas
automatizadas: consulta [el manual de Cinema](../SERVER/cinema/README.md).
Sus modificaciones más recientes necesitan desplegarse y verificarse en Ubuntu.

## 6. Servicios no web

Desde la raíz del repositorio, en **el servidor**:

```bash
make status
make check-cinema
make check-ftp
make check-ssh
make check-sockets
make test-sockets
```

Estas verificaciones son independientes. Si un comando falla, revisa el manual
de su módulo antes de reinstalarlo. Las pruebas de instalación y acceso real
requieren credenciales y una instancia Ubuntu configurada; GitHub Actions no
sustituye ese ambiente.

## 7. Prueba desde otra computadora

En el **servidor**:

```bash
ip -br -4 addr
```

En la **computadora administradora**, verifica que el tráfico irá por la LAN:

```bash
hostname
ip route get 192.168.244.135
```

La IP anterior fue la del servidor durante las pruebas del 20 de octubre; si
cambió, sustitúyela por la actual. Si la salida incluye
`local ... dev lo`, estás probando desde el propio servidor,
**no** desde una segunda computadora.

Con un repositorio compilado en la computadora administradora:

```bash
make -C C0DE/sockets
C0DE/sockets/out/echo_tcp_client 192.168.244.135 7 "Echo TCP LAN"
C0DE/sockets/out/echo_udp_client 192.168.244.135 7 "Echo UDP LAN"
C0DE/sockets/out/daytime_tcp_client 192.168.244.135 13
C0DE/sockets/out/daytime_udp_client 192.168.244.135 13
```

Comprobar también por LAN la web, HTTPS/Cinema, FTPS y SSH/SFTP según la
guía de cada servicio. No publiques contraseñas en capturas o terminales.

## 8. Capturas de Wireshark

Inicia Wireshark **en la interfaz LAN del equipo cliente**, antes de ejecutar
los programas anteriores, y utiliza este filtro de visualización:

```text
ip.addr == 192.168.244.135 && (tcp.port == 7 || udp.port == 7 || tcp.port == 13 || udp.port == 13)
```

En TCP identifica el intercambio SYN/SYN-ACK/ACK y la carga útil.
En UDP comprueba datagramas de ida y vuelta, sin establecimiento de sesión.
Guarda el archivo `.pcapng` y capturas de pantalla sin exponer cuentas
ni información privada.

**No dar por concluida la evidencia LAN hasta comprobar que
la computadora cliente y el servidor son equipos distintos.**
