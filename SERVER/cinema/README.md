# GutsCinema

Biblioteca privada de videos y música de GutsNet, servida por Apache y PHP en Ubuntu.
URL: **https://gutsnet.test/cinema/**.

## Activar en el servidor

Desde la rama que contiene estos archivos, dentro de `~/GutsNet`:

```bash
make install-cinema
make test-cinema
```

El primer comando pide la contraseña de `sudo` y después solicita crear la
contraseña de la cuenta **cine**. Es una cuenta de la biblioteca; no crea un
usuario de Linux. El segundo comando pide esa contraseña y comprueba el
catálogo, lectura parcial y carga/eliminación de archivos propios de prueba.

El instalador:

- Instala los paquetes de Apache, PHP y las herramientas necesarias.
- Crea `/home/gutsnet-shared/peliculas` si todavía no existe y permite a Apache
  escribir solo en esta biblioteca. El padre compartido y el área FTP conservan
  sus permisos. `.incoming/` queda privada para recibir archivos antes de publicarlos.
- Configura PHP para recibir un archivo de hasta **2 GiB** (2048 MiB), con margen
  para el formulario multipart y hasta una hora para recibirlo.
- En equipos con systemd, instala una excepción `ReadWritePaths` únicamente para
  `/home/gutsnet-shared/peliculas`. Permite gestionar Cinema cuando el servicio de
  Apache tiene `ProtectHome=read-only`, como en paquetes recientes de Debian/Ubuntu.
- Conserva el área de FTP, las películas existentes y el contador de visitas.
- Reutiliza un certificado TLS existente que cubra `gutsnet.test`. Si no hay
  certificado ni llave, crea una CA local y un certificado para el nombre del
  servidor y sus IPv4 actuales.
- Guarda las cuentas en `/etc/gutsnet/cinema.htpasswd` y las llaves fuera de Git.
- Conserva las contraseñas existentes al repetir la instalación.
- Respalda los VirtualHosts anteriores en `/var/backups/gutsnet/cinema/`.
- Desactiva el sitio de ejemplo `000-default` conservando su configuración, activa
  HTTP/HTTPS de GutsNet, publica la web y reinicia Apache.
- Agrega `Prueba_GutsCinema.mp4`, una copia del video de demostración del proyecto,
  si ese archivo no existe. No reemplaza otras películas.

Las dependencias necesitan conexión a los repositorios de Ubuntu. La biblioteca
no requiere Internet para reproducir los videos después de instalarse.

## Nombre del servidor y HTTPS

En el propio Ubuntu, `gutsnet.test` debe resolver a una dirección del servidor.
Si todavía no está definido en `/etc/hosts`, agrega:

```text
127.0.0.1 gutsnet.test
```

En un teléfono u otro equipo de la misma red, abre la **IP LAN actual del servidor**,
que puedes consultar con `hostname -I`, por ejemplo:

```text
http://192.168.244.135/
https://192.168.244.135/cinema/
```

La IP es un ejemplo: usa la de la interfaz que llega a tu red, no la de Docker.
El enlace Cinema y su redirección a HTTPS conservan esa IP. La cuenta y los medios
siguen protegidos por HTTPS. Aplica la configuración con `make install-cinema`;
`make deploy` no instala los VirtualHosts.

`DNS_PROBE_FINISHED_NXDOMAIN` en `gutsnet.test` significa que ese dispositivo no
resuelve el nombre. El `/etc/hosts` del servidor solo afecta al servidor. Para usar
el nombre en el teléfono, configura un DNS de la red que lo resuelva a la IP LAN y
haz que el teléfono use ese DNS. Cambiar el DNS por uno público no crea este nombre.
Puedes usar directamente la IP sin configurar DNS.

El puerto TCP 443 debe estar permitido y la IP debe ser alcanzable desde el teléfono;
el instalador no cambia las reglas de red. Si Ubuntu está en una máquina virtual,
su interfaz debe permitir conexiones desde la LAN (por ejemplo, adaptador puente).

Si se crea la CA local, su certificado público queda en
`/etc/ssl/certs/gutsnet-ca.crt`. Impórtalo en las autoridades de confianza del
navegador de los equipos que usarán la biblioteca. Solo se comparte el archivo
`.crt` público; la llave de la CA permanece en `/etc/gutsnet/tls/ca.key`.
Si se reutiliza tu certificado anterior, se conserva su configuración de confianza.

`make check-cinema` muestra las IPv4 del servidor e indica cuáles están incluidas
en el certificado. Un certificado anterior que solo cubra `gutsnet.test` necesita
DNS local para ese nombre, o un certificado nuevo que también cubra la IP. No se
reemplaza el certificado compartido con FTPS al corregir la redirección.

Para probar desde Ubuntu la identidad TLS, reproducción y carga/baja usando la IP:

```bash
bash SERVER/cinema/test.sh --host 192.168.244.135
```

Esta prueba conecta a Apache por loopback conservando la IP como identidad TLS y
Host; no verifica la ruta de red desde el teléfono. En el teléfono también debes
confiar en la CA local para que HTTPS sea válido.

Las pruebas usan `curl --cacert` y verifican nombre y cadena TLS; no necesitan
omitir la validación del certificado ni modificar la confianza global del sistema.
El certificado nuevo dura un año. Si después cambia la IP, el nombre
`gutsnet.test` sigue funcionando al actualizar su resolución local.

## Administrar desde el navegador

Después de actualizar la rama, ejecuta **`make install-cinema` una vez** para
aplicar los nuevos permisos y la configuración de carga; `make deploy` por sí
solo actualiza el código público.

Si no aparecen los controles o fallan tanto la carga como la eliminación, aplica
la reparación y comprueba el resultado:

```bash
git pull --ff-only
make install-cinema
make test-cinema
```

La reinstalación corrige el propietario y los permisos de la carpeta de Cinema,
su área de carga y su bloqueo de escritura, incluso si quedaron creados por root.
Conserva los archivos y las cuentas existentes. `make check-cinema` identifica
los permisos pendientes antes de intentar una carga.

Si la terminal permite escribir pero el catálogo oculta los controles, el servicio
de Apache puede estar viendo `/home` como solo lectura. `make check-cinema` revisa
también el entorno de montajes del servicio. `make install-cinema` instala
`/etc/systemd/system/apache2.service.d/gutsnet-cinema.conf`, recarga systemd y reinicia
Apache. La excepción habilita la carpeta de Cinema y conserva la protección del
resto de `/home`.

1. Abre **https://gutsnet.test/cinema/** con tu cuenta habitual.
2. En «Agrega un video o una canción», selecciona un **MP4 o MP3** y pulsa
   **Subir archivo**. Se muestra el progreso; conserva la pestaña abierta.
3. Cuando termine, aparecerá en la biblioteca. Los MP3 tienen reproductor de audio.
4. Para borrar, abre **Eliminar archivo** en su tarjeta y confirma con
   **Sí, eliminar archivo**. Esto elimina ese archivo del disco del servidor.

El límite es **2 GiB por archivo**. Un nombre existente se rechaza sin reemplazarlo:
cambia el nombre en tu dispositivo si quieres conservar ambas versiones. Si la
conexión se interrumpe, revisa primero el catálogo antes de volver a enviar el archivo.
El formulario y la confirmación de baja también funcionan sin JavaScript, sin barra
de progreso.

Todas las cuentas válidas de Cinema pueden reproducir, agregar y eliminar archivos.
No hay un rol de administrador separado. Las solicitudes de cambio requieren POST
y un token CSRF asociado a una sesión con cookie Secure, HttpOnly y SameSite=Strict.
El servidor revisa nombre, tamaño y contenido MIME; rechaza rutas, enlaces y extensiones
falsas. Los archivos nuevos se preparan en un área privada y se publican sin sobrescribir
destinos. La confirmación incluye una versión del archivo para rechazar bajas de una
tarjeta desactualizada.

No se modifican los archivos de audio del portafolio ni los del área FTP. Los medios
privados permanecen fuera de la raíz web y de Git.

## Agregar un archivo desde la terminal

Desde un archivo que ya esté en el servidor:

```bash
sudo bash SERVER/cinema/add.sh "/ruta/a/Mi pelicula.mp4"
```

Para asignarle otro nombre:

```bash
sudo bash SERVER/cinema/add.sh "/ruta/video.mp4" "Mi pelicula.mp4"
```

La importación copia el archivo a la carpeta privada con permisos de lectura
para Apache y rechaza nombres que ya existan. No modifica la fuente.
El catálogo se actualiza al recargar la página.

La terminal y el catálogo admiten **MP4, MP3, WebM y OGV**. El formulario web
acepta **MP4 y MP3**. El contenedor no garantiza que el códec se pueda
reproducir en cada navegador; el servidor entrega el archivo original, sin
transcodificarlo. Los videos privados no se guardan en `C0DE/web/public`, en
`/var/www/gutsnet/public` ni en Git.

## Cuentas

Para crear otra cuenta o cambiar la contraseña de una existente:

```bash
sudo htpasswd -B /etc/gutsnet/cinema.htpasswd otro_usuario
```

No uses `-c`: reemplazaría el archivo de cuentas. Si eliges una cuenta distinta
de `cine`, prueba con:

```bash
bash SERVER/cinema/test.sh --user otro_usuario
```

La autenticación Basic conserva la sesión en el navegador; el catálogo no
incluye un botón de cierre de sesión que prometa eliminar esas credenciales.

## Comprobaciones

```bash
make check-cinema  # configuración, certificado, permisos y acceso sin cuenta
make test-cinema   # cuenta, reproducción y carga/baja de archivos propios de prueba
make test-web      # web pública, multimedia y contador
```

Resultados previstos:

| Solicitud | Resultado |
| --- | --- |
| HTTP `/cinema/` | 302 a HTTPS |
| HTTPS `/cinema`, catálogo o video sin cuenta | 401 |
| Catálogo con cuenta correcta | 200 y PHP ejecutado |
| Gestión sin cuenta | 401 |
| GET autenticado a `/cinema/manage.php` | 405 |
| Gestión sin token CSRF válido | 403 |
| Carga válida de MP4 o MP3 | 201 |
| Nombre de archivo duplicado | 409, archivo anterior intacto |
| Extensión o contenido no admitidos | 415 |
| Baja de archivo cambiado desde la consulta | 409 |
| Baja válida | 200 (JSON) o 303 (formulario HTML) |
| Video con cuenta y `Range: bytes=0-15` | 206 y 16 bytes |
| Archivo PHP en la carpeta de películas | 403 |
| Symlink o ruta con información adicional | 403 o 404 |

El catálogo ignora archivos ocultos, vacíos, enlaces simbólicos y formatos no
admitidos. Apache desactiva ejecución de scripts y lectura de enlaces en el área
multimedia. Los archivos de video se sirven directamente para conservar Range.

Para diagnosticar un fallo:

```bash
sudo apache2ctl configtest
sudo journalctl -u apache2 -n 50 --no-pager
sudo tail -n 50 /var/log/apache2/gutsnet_ssl_error.log
```

GitHub Actions instala el servicio en un Ubuntu aislado, comprueba autenticación,
HTTPS, Range, reinstalación, carga/baja de MP4 y MP3, CSRF, nombres duplicados y
rechazo de archivos ajenos a la biblioteca. Las pruebas de gestión usan nombres
aleatorios y solo eliminan los archivos creados por esas mismas pruebas.
El resultado de CI no confirma por sí solo la activación del equipo del usuario.

Referencias: [autenticación de Apache](https://httpd.apache.org/docs/2.4/howto/auth.html),
[htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) y
[secciones de configuración](https://httpd.apache.org/docs/2.4/sections.html),
[carga de archivos en PHP](https://www.php.net/manual/en/features.file-upload.post-method.php)
y [move_uploaded_file](https://www.php.net/manual/en/function.move-uploaded-file.php).
