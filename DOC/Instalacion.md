# Instalación y configuración de GutsNet

> Los cambios de este repositorio NO configuran automáticamente el sistema.
> Las operaciones con `sudo` se realizan de manera explícita en el servidor.
> Ejecutar desde la raíz `~/GutsNet` tras integrar la rama de desarrollo.

## 0. Antes de modificar Ubuntu

Revisa primero [Arquitectura](Arquitectura.md) y ejecuta desde la copia
local del repositorio:

```bash
git status -sb
git pull --ff-only origin main
make help
make status
```

**Mantén abierta una sesión SSH administrativa** antes de actualizar SSH Jail.
Confirma los respaldos de configuración y no borres directorios privados.
El sitio y la base de datos conservan rutas independientes. Cinema, FTPS y SSH
pueden compartir su biblioteca después de la migración explícita.

## 1. Web pública

Dependencias de Ubuntu:

```bash
sudo apt update
sudo apt install apache2 rsync php libapache2-mod-php php-sqlite3 curl
```

Instalar las configuraciones del repositorio:

```bash
sudo install -m 644 SERVER/apache/servername.conf /etc/apache2/conf-available/servername.conf
sudo install -m 644 SERVER/apache/gutsnet.conf /etc/apache2/sites-available/gutsnet.conf
sudo a2enconf servername
sudo a2ensite gutsnet.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

La configuración del ejemplo usa el nombre `gutsnet.test`. En el propio
servidor, añadir a `/etc/hosts` `127.0.0.1 gutsnet.test` si no está definido.
En otra computadora de la red, asociar `gutsnet.test` a la dirección IP LAN
actual del servidor mediante `/etc/hosts` o DNS local.

La web utiliza la base de datos persistente
`/var/lib/gutsnet/visitas.sqlite`. Antes de probar el contador, crear el
directorio **fuera de la web** y hacerlo escribible para Apache:

```bash
sudo install -d -o www-data -g www-data -m 750 /var/lib/gutsnet
```

Si la base ya existe, no borrar ni sustituir el archivo; verificar primero
sus permisos. Publicar y probar:

```bash
make preview
make deploy
make test
make test-web
```

## 2. GutsCinema: biblioteca privada

Desde `~/GutsNet`, con la rama principal ya actualizada:

```bash
make install-cinema
make test-cinema
```

El instalador prepara Apache, HTTPS, almacenamiento privado y la cuenta web `gutsjail`.
Solicita la contraseña de forma interactiva y conserva la existente al repetirse.
La biblioteca se abre en **https://gutsnet.test/cinema/**.

Para agregar un video del servidor:

```bash
sudo bash SERVER/cinema/add.sh "/ruta/a/pelicula.mp4"
```

Consulta [SERVER/cinema/README.md](../SERVER/cinema/README.md) para resolver el
nombre en otros equipos, configurar la confianza del certificado local, agregar
cuentas y revisar las pruebas de autenticación y reproducción.

La activación ocurre al ejecutar el instalador en Ubuntu; `git pull` no cambia
los servicios ni crea credenciales por sí solo.

## 3. FTPS (vsftpd)

```bash
sudo bash SERVER/ftp/install.sh --check
make install-ftp
sudo passwd gutsftp             # solo si la cuenta no tiene credencial válida
make check-ftp
```

El servicio usa el puerto TCP 21, modo pasivo 40000–40010 y certificado TLS.
El almacenamiento de intercambio se encuentra fuera de la raíz pública de Apache.
En instalaciones anteriores, permanece separado de Cinema hasta migrarlo.
No copies contraseñas, certificados privados ni archivos personales al Git.

## 4. SSH Jail y SFTP

**No cierres la sesión SSH administrativa** mientras cambias OpenSSH:

```bash
sudo bash SERVER/ssh/install.sh --check
make install-ssh
sudo passwd gutsjail            # si todavía no existe una contraseña válida
make check-ssh
```

El usuario `gutsjail` accede a `/compartido` dentro de su chroot.
Antes de migrar, FTPS y SFTP comparten solamente el directorio de intercambio. Para actualizar
los comandos permitidos en la shell C después de un cambio del código,
no basta con `git pull`: hay que instalar y verificar la nueva versión.
Consulta [SSH Jail](../SERVER/ssh/README.md).

## 5. Unificar Cinema, SSH/SFTP y FTPS

Si los tres servicios ya están instalados, sigue [la guía de migración](../SERVER/shared/README.md).
Primero ejecuta `sudo bash SERVER/shared/unify.sh --check`; la aplicación se
realiza exclusivamente con `--apply`, durante una pausa de las sesiones de archivos.
Después reinstala Cinema y ejecuta `make check-shared` y las verificaciones de cada servicio.
Conserva la sesión administrativa abierta y prueba las interfaces antes de retirar cuentas anteriores.

## 6. Echo y Daytime mediante systemd

```bash
sudo bash SERVER/sockets/install.sh --check
make install-sockets
make check-sockets
make test-sockets
```

Se habilitan cuatro servicios en los puertos oficiales 7 y 13 TCP/UDP.
Se ejecutan con permisos restringidos, no como `root`. El instalador
no modifica Apache, FTP ni SSH.

## 7. Comprobación final

```bash
make status
make test-web
make check-cinema
make check-ftp
make check-ssh
make check-sockets
```

No reinstales módulos ya activos por rutina; usa `make install-*`
solo cuando realmente necesites aplicar la configuración del repositorio.
Revisa [Pruebas](Pruebas.md) para los clientes remotos y Wireshark.
El CV y las capturas de evaluación se gestionan por separado.
