# GutsCinema

Biblioteca privada de videos de GutsNet, servida por Apache y PHP en Ubuntu.
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
catálogo y la lectura parcial de un video.

El instalador:

- Instala los paquetes de Apache, PHP y las herramientas necesarias.
- Crea `/home/gutsnet-shared/peliculas` si todavía no existe.
- Conserva el área de FTP, las películas existentes y el contador de visitas.
- Reutiliza un certificado TLS existente que cubra `gutsnet.test`. Si no hay
  certificado ni llave, crea una CA local y un certificado para el nombre del
  servidor y sus IPv4 actuales.
- Guarda las cuentas en `/etc/gutsnet/cinema.htpasswd` y las llaves fuera de Git.
- Conserva las contraseñas existentes al repetir la instalación.
- Respalda los VirtualHosts anteriores en `/var/backups/gutsnet/cinema/`.
- Activa HTTP/HTTPS, publica la web y reinicia Apache.
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

En otra computadora de la red usa la **IP LAN actual del servidor**, que puedes
consultar con `hostname -I`, en lugar de `127.0.0.1`. El puerto TCP 443 debe
estar permitido en el firewall de esa red; el instalador no cambia sus reglas.

Si se crea la CA local, su certificado público queda en
`/etc/ssl/certs/gutsnet-ca.crt`. Impórtalo en las autoridades de confianza del
navegador de los equipos que usarán la biblioteca. Solo se comparte el archivo
`.crt` público; la llave de la CA permanece en `/etc/gutsnet/tls/ca.key`.
Si se reutiliza tu certificado anterior, se conserva su configuración de confianza.

Las pruebas usan `curl --cacert` y verifican nombre y cadena TLS; no necesitan
omitir la validación del certificado ni modificar la confianza global del sistema.
El certificado nuevo dura un año. Si después cambia la IP, el nombre
`gutsnet.test` sigue funcionando al actualizar su resolución local.

## Agregar una película

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

Se aceptan **MP4, WebM y OGV**. El contenedor no garantiza que el códec se pueda
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
make test-cinema   # cuenta válida, catálogo PHP y reproducción parcial
make test-web      # web pública, multimedia y contador
```

Resultados previstos:

| Solicitud | Resultado |
| --- | --- |
| HTTP `/cinema/` | 302 a HTTPS |
| HTTPS `/cinema`, catálogo o video sin cuenta | 401 |
| Catálogo con cuenta correcta | 200 y PHP ejecutado |
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
HTTPS, Range, reinstalación y rechazo de archivos ajenos a la biblioteca.
El resultado de CI no confirma por sí solo la activación del equipo del usuario.

Referencias: [autenticación de Apache](https://httpd.apache.org/docs/2.4/howto/auth.html),
[htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) y
[secciones de configuración](https://httpd.apache.org/docs/2.4/sections.html).
