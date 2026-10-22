# Instalación y configuración de GutsNet

> Los cambios de este repositorio NO configuran automáticamente el sistema.
> Las operaciones con `sudo` se realizan de manera explícita en el servidor.
> Ejecutar desde la raíz `~/GutsNet` tras integrar la rama de desarrollo.

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

Desde `~/GutsNet`, en la rama que contiene el instalador:

```bash
make install-cinema
make test-cinema
```

El instalador prepara Apache, HTTPS, almacenamiento privado y la cuenta `cine`.
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

## 3. Pendientes

- Incorporar el CV cuando exista.
- Completar las páginas de prácticas de materias.
- Configurar FTPS y el usuario SSH restringido por chroot.
- Crear servicios TCP/UDP Echo y Daytime en C.
- Documentar capturas con Wireshark.
