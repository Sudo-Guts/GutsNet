# Una biblioteca multimedia — GutsNet

## Objetivo

Solo dos usuarios de uso cotidiano: **guts** (administrador Linux) y
**gutsjail** (usuario restringido). www-data y root son cuentas técnicas.
gutsjail accede a la misma colección multimedia por Cinema/HTTPS, SSH/SFTP
y FTPS, con permisos de lectura, creación y eliminación.

**Nota sobre credenciales:** el inicio web usa Apache Basic Auth y un
hash en /etc/gutsnet/cinema.htpasswd; SSH/SFTP y FTPS utilizan el password
de la cuenta Linux. El NOMBRE es el mismo, pero las contraseñas no tienen
que ser iguales. No se instaló autenticación PAM en Apache.

Biblioteca canónica: /home/gutsnet-shared/peliculas
Montaje SSH: /home/gutsnet-jail/compartido
Montaje FTPS: /home/gutsnet-shared/ftp/intercambio

Las tres rutas señalan el mismo directorio, sin duplicar archivos.
vsftpd entra primero al home Linux antes de aplicar su chroot. Para conservar
el home `/compartido` de SSH, la migración prepara en el host un directorio
vacío `/compartido`, root:root 755. No contiene ni monta archivos de usuario;
la ruta con ese nombre dentro del jail sí apunta a la biblioteca. Si el
directorio del host ya existe con otros datos o permisos, se detiene sin alterarlo.
El staging de Cinema se mueve fuera de la biblioteca, a
/home/gutsnet-shared/.cinema-incoming, privado para www-data.

## Migración segura (ejecución EXPLÍCITA, no automática)

No ejecutar estos pasos hasta estar frente a Ubuntu o disponer de una
segunda consola administrativa SSH abierta. Respaldar previamente las
películas importantes. La migración detiene temporalmente Apache y vsftpd.

1. Actualizar código de la rama con esta funcionalidad y comprobar:

    sudo bash SERVER/shared/unify.sh --check

2. Crear la entrada web para el único usuario, sin compartir la contraseña:

    sudo htpasswd -B /etc/gutsnet/cinema.htpasswd gutsjail

3. Cerrar sesiones SFTP, FTPS y subidas web. Aplicar durante mantenimiento:

    sudo bash SERVER/shared/unify.sh --apply

   La herramienta detecta colisiones de nombres antes de detener servicios, copia el antiguo intercambio
   sin sobrescribir archivos Cinema, preserva un respaldo antiguo y guarda
   una copia de /etc/fstab. No elimina archivos de usuario. Si falla entre
   pasos, no repetir automáticamente: revisar montajes y respaldos. Una migración
   terminada sí puede repetirse: verifica el estado sin duplicar montajes ni respaldos.

4. Actualizar Cinema INMEDIATAMENTE para utilizar staging privado:

    make install-cinema

5. Verificar:

    make check-shared
    make check-cinema
    make check-ssh
    make check-ftp

6. Validar operaciones cruzadas con MP3/MP4 de prueba:
   subir por Cinema y descargar por SFTP; subir por SFTP y reproducir en
   Cinema; subir/descargar por FTPS con el login gutsjail; borrar desde web
   y comprobar en terminal; confirmar aislamiento y permisos sin sudo.

La consola admite nombres como `"Mi canción.mp3"`; deben escribirse entre
comillas cuando contienen espacios. No interpreta variables ni programas.
Cinema muestra archivos multimedia del nivel principal; los subdirectorios
se administran mediante SSH/SFTP y FTPS.

## Pruebas automatizadas

GitHub Actions instala los tres servicios en Ubuntu 24.04 y 26.04, prepara datos del
almacenamiento anterior y ejecuta la migración real. Comprueba rechazo de
colisiones, conservación del contenido, credenciales y certificados,
reinstalación, repetición sin cambios, permisos privados del staging y rechazo
de ACL que niegan escritura a www-data o gutsjail.
Después usa `tests/test_interfaces.py` para subir por HTTPS/SFTP/FTPS,
comparar descargas, reproducir rangos HTTP y eliminar desde otra interfaz.
Las pruebas usan archivos con espacios y acentos, conservan el aislamiento
del jail y comprueban que las credenciales anteriores no permitan entrar.
Estas pruebas de un servidor temporal no sustituyen la verificación en la LAN.

## Comprobación de permisos en Ubuntu 26.04

`test` de rust-coreutils 0.10.0 no evalúa correctamente las ACL ni los grupos
suplementarios. Puede rechazar una biblioteca accesible o aceptar permisos
que una ACL niega. Los instaladores y verificaciones ejecutan el `test`
integrado de Bash bajo la identidad correspondiente, también dentro del
espacio de montajes de Apache. Se conservan las comprobaciones de lectura,
recorrido, escritura y aislamiento. La opción `-p` evita cargar funciones y
archivos de inicio desde el entorno; no otorga privilegios al usuario.
El despliegue también establece explícitamente el modo 755 del directorio
padre de la web para que una instalación nueva con umask 077 sea recorrible
por Apache.

Referencia: [fallo de test en Ubuntu 26.04](https://github.com/actions/runner-images/issues/15004).

## Retirar credenciales antiguas (solo al terminar las pruebas)

La autorización FTPS se limita a gutsjail mediante la migración. Una vez
confirmado el ingreso por FTPS como gutsjail, deshabilitar la contraseña
de la antigua cuenta FTP:

    sudo passwd -l gutsftp

El VirtualHost de Cinema solo permite gutsjail, aunque la entrada cine
siga en htpasswd. Cuando Cinema haya sido probado con gutsjail:

    sudo htpasswd -D /etc/gutsnet/cinema.htpasswd cine

No eliminar usuarios Linux con userdel -r: evita pérdidas de archivos
antiguos. Las cuentas del sistema no cuentan como usuarios finales.

Diagnóstico:
    findmnt /home/gutsnet-jail/compartido
    findmnt /home/gutsnet-shared/ftp/intercambio
    sudo getfacl /home/gutsnet-shared/peliculas
    sudo systemctl status apache2 vsftpd ssh --no-pager
