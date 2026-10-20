# Pruebas de la web de GutsNet

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

El CV y la biblioteca privada GutsNet Cinema todavía están pendientes.
Las pruebas de privacidad, autenticación y HTTPS se agregarán cuando estén
implementadas.
