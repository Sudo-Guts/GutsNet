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

Publicar y probar:

```bash
make preview
make deploy
make test
make test-web
```

La web utiliza la base de datos persistente
`/var/lib/gutsnet/visitas.sqlite`. Crear el directorio **fuera de la web**
y hacerlo escribible para el proceso de Apache:

```bash
sudo install -d -o www-data -g www-data -m 750 /var/lib/gutsnet
```

Si la base ya existe, no borrar ni sustituir el archivo. Verificar sus
permisos antes de modificarla. Luego repetir `make test-web`.

## 2. GutsNet Cinema: contenido privado

El catálogo está en `C0DE/web/public/cinema/index.php`, pero **no debe
publicarse como biblioteca accesible por HTTP**. El PHP devuelve 403 sin
HTTPS. Apache debe autenticar tanto el catálogo como **cada URL del video**.

### 2.1. Directorio de películas

```bash
sudo install -d -o root -g root -m 755 /home/gutsnet-shared
sudo install -d -o root -g www-data -m 750 /home/gutsnet-shared/peliculas
```

Si esas carpetas ya existen y son utilizadas por FTP, revisar primero
la propiedad y los permisos: no aplicar cambios que interrumpan el
almacenamiento compartido.

Para añadir una película desde un archivo local del servidor:

```bash
sudo install -o root -g www-data -m 640 \
    /ruta/al/video.mp4 \
    /home/gutsnet-shared/peliculas/video.mp4
```

Se admiten archivos `.mp4`, `.webm` y `.ogv`. Los archivos privados nunca
deben copiarse a `C0DE/web/public` o `/var/www/gutsnet/public`.

### 2.2. Usuario y contraseña (fuera de Git)

```bash
sudo apt install apache2-utils
sudo install -d -o root -g www-data -m 750 /etc/gutsnet
sudo htpasswd -c -B /etc/gutsnet/cinema.htpasswd cine
sudo chown root:www-data /etc/gutsnet/cinema.htpasswd
sudo chmod 640 /etc/gutsnet/cinema.htpasswd
```

`htpasswd` solicitará la contraseña de forma interactiva. No registrar
la contraseña en Git ni en comandos que la expongan en el historial.

**La opción `-c` crea o reemplaza el archivo**: usarla solo para
la primera cuenta. Para agregar cuentas adicionales, ejecutar
`sudo htpasswd -B /etc/gutsnet/cinema.htpasswd otro_usuario`
(sin `-c`).

### 2.3. Certificado HTTPS para laboratorio

En un entorno académico de red local se puede generar un certificado
autofirmado. Ajustar la dirección IP si cambia:

```bash
sudo openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
    -days 365 \
    -keyout /etc/ssl/private/gutsnet.key \
    -out /etc/ssl/certs/gutsnet.crt \
    -subj "/CN=gutsnet.test" \
    -addext "subjectAltName=DNS:gutsnet.test,IP:192.168.244.135"

sudo chmod 600 /etc/ssl/private/gutsnet.key
sudo chmod 644 /etc/ssl/certs/gutsnet.crt
```

El certificado autofirmado no será confiable por defecto en los
navegadores. Para un despliegue real o para evitar alertas, utilizar
una autoridad de certificación confiable o una CA local instalada
explícitamente en los equipos autorizados. No ignorar advertencias
TLS ante un certificado desconocido.

### 2.4. Activación de Apache SSL

Instalar los dos VirtualHosts del repositorio y habilitar módulos:

```bash
sudo install -m 644 SERVER/apache/gutsnet.conf \
    /etc/apache2/sites-available/gutsnet.conf

sudo install -m 644 SERVER/apache/gutsnet-ssl.conf \
    /etc/apache2/sites-available/gutsnet-ssl.conf

sudo a2enmod ssl auth_basic alias
sudo a2ensite gutsnet-ssl.conf

sudo apache2ctl configtest
sudo systemctl reload apache2
make deploy
```

El VirtualHost del puerto 80 redirige `/cinema/` a HTTPS. El VirtualHost
del puerto 443 protege `/cinema/` mediante autenticación Basic y
sirve los archivos del Alias `/cinema/media/` con las mismas restricciones.

Para que otro equipo acceda a HTTPS, debe poder llegar al puerto TCP 443.
Si UFW está activo, revisar sus reglas antes de permitir ese puerto.

### 2.5. Pruebas de autenticación

Desde el servidor:

```bash
# Debe ser HTTP 302 con redirección a HTTPS.
curl -I -H "Host: gutsnet.test" \
    http://127.0.0.1/cinema/

# Sin credenciales debe responder HTTP 401.
# --cacert confía SOLO en el certificado de laboratorio indicado.
curl -I --cacert /etc/ssl/certs/gutsnet.crt \
    --resolve gutsnet.test:443:127.0.0.1 \
    https://gutsnet.test/cinema/

# Con credenciales correctas debe responder HTTP 200.
# curl solicita la contraseña interactivamente.
curl -I --cacert /etc/ssl/certs/gutsnet.crt \
    --resolve gutsnet.test:443:127.0.0.1 \
    -u cine \
    https://gutsnet.test/cinema/
```

**Prueba de seguridad obligatoria:** una petición no autenticada a
`https://gutsnet.test/cinema/media/video.mp4` también debe devolver
HTTP 401. Con credenciales, el archivo debe reproducirse y permitir
solicitudes HTTP Range. No almacenar películas públicas como si
estuvieran protegidas por el catálogo.

## 3. Pendientes

- Incorporar el CV cuando exista.
- Completar las páginas de prácticas de materias.
- Configurar FTPS y el usuario SSH restringido por chroot.
- Crear servicios TCP/UDP Echo y Daytime en C.
- Documentar capturas con Wireshark.
