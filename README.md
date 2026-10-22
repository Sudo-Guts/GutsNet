# GutsNet

Proyecto académico de **administración de servidores Linux, desarrollo web
y programación de sockets**. Entorno objetivo: Ubuntu 26.04 LTS.

## Estado de implementación

### Web pública (código disponible)

- Sitio personal en HTML, CSS y JavaScript.
- Fondo blanco y acentos pastel en lavanda, azul, verde y durazno.
- CSS, JavaScript e ilustraciones con versiones por contenido para evitar caché obsoleta.
- Portada con una señal senoidal sintética ajustable, de un segundo de duración.
- Catálogo con filtros de hardware, señales, Linux y redes.
- Navegación adaptable con menú móvil; contenido accesible sin JavaScript.
- Secciones: presentación, intereses, cuatro materias y enlaces a proyectos.
- Reproductor musical con dos pistas MP3.
- Video de demostración MP4 mediante HTML5.
- Contador de cargas de página con PHP y SQLite.
- Apache con VirtualHost `gutsnet.test`.
- Despliegue con `make preview` / `make deploy`.
- Pruebas HTTP integrales mediante `make test-web`.

**Importante:** disponer del código en GitHub no confirma el estado actual
del servicio de Apache ni de la base de datos del servidor. La comprobación
operativa se realiza desde Ubuntu mediante `make test-web`.

### Pendiente

- Incorporar el CV (todavía no disponible).
- Activar GutsCinema en el Ubuntu del usuario mediante `make install-cinema`; el instalador y las pruebas están disponibles en el repositorio.
- Servicio FTP con directorio compartido.
- Usuario SSH restringido mediante chroot (el acceso administrador ya fue probado).
- Capturas de tráfico y pruebas finales con Wireshark.

## Estructura

- `C0DE/web/public/` — contenido publicado por Apache.
- `C0DE/web/app/` — futuras funciones privadas del sitio.
- `C0DE/web/storage/` — almacenamiento local no publicado por Git.
- `C0DE/sockets/` — código de clientes y servidores en C.
- `SERVER/` — archivos de configuración de Apache, SSH, FTP y sockets.
- `DOC/CheckList.md` — progreso de las etapas.
- `DOC/Pruebas.md` — procedimientos de verificación.
- `scripts/test-web.sh` — prueba integral HTTP de la página.

## Comandos principales

Desde la raíz de GutsNet en el **servidor**:

```bash
make preview    # Mostrar diferencias antes de desplegar
make deploy     # Sincronizar la página con /var/www/gutsnet/public
make test       # Comprobar HTTP 200 en la página de inicio
make test-web   # Verificar páginas, CSS, JS, MP3, MP4 y contador
```

El destino de `make deploy` se sincroniza con `rsync --delete`:
**no se deben guardar archivos privados directamente en
`/var/www/gutsnet/public`**.

Los archivos multimedia privados, el entorno chroot y el área de archivos
compartidos se almacenarán fuera de la raíz web, en la partición `/home`.

## GutsCinema

Catálogo privado con búsqueda y reproducción de videos mediante Apache y PHP.
La cuenta protege también las URL directas de los archivos. Las películas se
almacenan en `/home/gutsnet-shared/peliculas`, fuera de la raíz pública.

```bash
make install-cinema  # prepara paquetes, TLS, cuenta cine y Apache
make check-cinema    # revisa configuración y acceso privado
make test-cinema     # prueba la cuenta y la reproducción parcial
```

Para importar videos, configurar la confianza HTTPS y acceder desde otros
equipos, consulta [SERVER/cinema/README.md](SERVER/cinema/README.md).
La existencia del instalador no implica que ya esté activo en tu Ubuntu.

## Clientes Echo y Daytime hacia servidores externos

Desde la raíz del repositorio:

```bash
make -C C0DE/sockets echo-remoto MESSAGE="Hola desde GutsNet"
make -C C0DE/sockets hora-remota
```

Echo consulta `tcpbin.com:4242` y Daytime consulta `time.nist.gov:13`,
ambos por TCP. Los comandos compilan su cliente y limitan la consulta completa
a 10 segundos. El host, el puerto, el mensaje y ese límite son configurables.

Para elegir otros destinos, usar UDP, capturar tráfico y ejecutar las pruebas,
consulta [SERVER/sockets/README.md](SERVER/sockets/README.md).

## Pruebas

Las comprobaciones del portafolio no requieren Apache ni paquetes de Node:

```bash
python3 scripts/check-web.py
python3 scripts/version-web-assets.py --check
node --check C0DE/web/public/assets/js/main.js
node scripts/test-web-ui.cjs
```

Verifican recursos y fragmentos locales, referencias de accesibilidad, geometría
de la señal y comportamiento de filtros, menú, contador y controles de audio.
Las pruebas de JavaScript usan un DOM mínimo; no comprueban el renderizado
ni sustituyen las pruebas multimedia en un navegador real.

Al modificar CSS, JavaScript o SVG, actualiza las referencias antes de publicar:

```bash
python3 scripts/version-web-assets.py
```

`make preview` y `make deploy` comprueban estas versiones. `make test-web`
compara el HTML, CSS y JavaScript entregados por Apache con los archivos de la
rama local: HTTP 200 por sí solo ya no basta para aprobar la publicación.
`GUTSNET_ASSETS_ONLY=1 make test-web` limita la prueba a estos recursos.
`bash scripts/test-web-publication.sh` prueba esta detección mediante un servidor
PHP temporal y copias deliberadamente desactualizadas de los recursos.

Consulta [DOC/Pruebas.md](DOC/Pruebas.md) para ejecutar pruebas de sintaxis,
servicios HTTP, tipos MIME, solicitudes parciales de video y persistencia
del contador.

## Seguridad

- No incorporar credenciales, llaves privadas, bases de datos ni películas
  privadas al repositorio.
- Mantener al usuario SSH restringido sin privilegios `sudo`.
- Configurar HTTPS **antes** de transmitir credenciales de GutsNet Cinema.
- Aplicar autenticación también a las URL directas de los archivos privados.
- Publicar únicamente archivos multimedia sobre los que se tengan derechos
  de distribución.

## Protocolos previstos

- Echo: RFC 862, TCP/UDP, puerto 7.
- Daytime: RFC 867, TCP/UDP, puerto 13.
