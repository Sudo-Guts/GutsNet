# GutsNet

Proyecto académico de **administración de servidores Linux, desarrollo web
y programación de sockets**. Entorno objetivo: Ubuntu 26.04 LTS.

## Estado de implementación

### Web pública (código disponible)

- Sitio personal en HTML, CSS y JavaScript.
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
- Activar GutsNet Cinema en Ubuntu: los archivos PHP y VirtualHost HTTPS están preparados en el repositorio, pero faltan certificado, credenciales, películas y pruebas en el servidor.
- Servicio FTP con directorio compartido.
- Usuario SSH restringido mediante chroot (el acceso administrador ya fue probado).
- Clientes y servidores en C: Echo RFC 862 y Daytime RFC 867 (TCP y UDP).
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

## GutsNet Cinema (configuración pendiente)

Se preparó un catálogo PHP protegido por Apache Basic Auth exclusivamente mediante HTTPS.
Los archivos audiovisuales se sirven desde `/home/gutsnet-shared/peliculas`, fuera del directorio público.
Para habilitarlo y comprobar que las URL directas exigen credenciales, sigue [DOC/Instalacion.md](DOC/Instalacion.md).

## Pruebas

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
