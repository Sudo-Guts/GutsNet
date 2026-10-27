# Arquitectura de GutsNet

El repositorio conserva código y plantillas. Ubuntu mantiene credenciales,
datos y procesos fuera de Git; cada instalación o migración es explícita.

## Servicios y almacenamiento

| Servicio | Acceso | Almacenamiento |
| --- | --- | --- |
| Portafolio | HTTP 80 y HTTPS 443 | /var/www/gutsnet/public |
| Contador PHP/SQLite | POST /api/visitas.php | /var/lib/gutsnet/visitas.sqlite |
| Cinema privado | HTTPS 443, /cinema/ | /home/gutsnet-shared/peliculas |
| FTPS explícito | TCP 21 y pasivos 40000–40010 | /home/gutsnet-shared/ftp/intercambio |
| SSH administrativo | TCP 22, usuario guts | Sistema Linux |
| SSH Jail/SFTP | TCP 22, usuario gutsjail | /home/gutsnet-jail/compartido |
| Echo RFC 862 | TCP y UDP 7 | Ejecutables en /usr/local/libexec/gutsnet |
| Daytime RFC 867 | TCP y UDP 13 | Ejecutables en /usr/local/libexec/gutsnet |

Después de la migración, las tres rutas de Cinema, FTPS y SSH Jail señalan
el mismo directorio mediante montajes bind. El almacenamiento canónico es
/home/gutsnet-shared/peliculas; los archivos no se duplican entre interfaces.
El staging /home/gutsnet-shared/.cinema-incoming es privado para www-data
y queda fuera de los directorios editables por gutsjail.

Antes de migrar, Cinema permanece separado de FTPS/SFTP. Los instaladores de
SSH y FTPS conservan ese estado hasta que la migración crea el marcador
/etc/gutsnet/media-unificada. Actualizar el repositorio no cambia montajes.

## Usuarios y permisos

Los usuarios de uso cotidiano son guts (administración) y gutsjail (archivos).
root y www-data son cuentas técnicas. La biblioteca usa el grupo
gutsnet-files, SGID y ACL heredables para compartir operaciones sin dar
privilegios administrativos a gutsjail.

Cinema autoriza únicamente el nombre gutsjail mediante Apache Basic Auth y
/etc/gutsnet/cinema.htpasswd. SSH/SFTP y FTPS autentican la cuenta Linux.
La contraseña web es independiente de la contraseña Linux; no hay
sincronización automática. Las credenciales anteriores se retiran después
de comprobar los tres accesos, según SERVER/shared/README.md.

## Capas del proyecto

| Ruta | Responsabilidad |
| --- | --- |
| C0DE/web/public | Aplicación y recursos publicados |
| C0DE/sockets | Clientes y servidores en C |
| SERVER/apache, cinema, ftp, ssh, sockets | Configuración, instalación y verificación |
| SERVER/shared | Migración explícita y pruebas de la biblioteca común |
| scripts | Pruebas web y versiones de recursos |
| .github/workflows | Validación en servidores temporales de GitHub Actions |
| DOC | Arquitectura, instalación, pruebas y pendientes |

No guardar películas privadas, bases de datos ni credenciales en el directorio
publicado: make deploy sincroniza esa ruta con rsync --delete.
Las configuraciones activas están en /etc/apache2, /etc/ssh y /etc/vsftpd.conf;
el material privado está en /etc/gutsnet y /etc/ssl/private.

## Dependencias y verificación

1. Preparar red, Ubuntu y SSH administrativo.
2. Instalar Apache/PHP/SQLite y publicar el sitio.
3. Configurar Cinema, HTTPS, FTPS y SSH Jail.
4. Revisar y aplicar la migración de SERVER/shared cuando corresponda.
5. Comprobar altas, bajas, descargas y reproducción entre interfaces.
6. Instalar o comprobar Echo/Daytime con systemd.
7. Probar desde otro equipo de la LAN y guardar evidencias de Wireshark.

Usar la IP del propio servidor desde el servidor puede seguir una ruta
local por lo; eso no prueba comunicación entre dos computadoras.

make help, make status y los objetivos make check-* consultan el estado.
make test-* ejecuta pruebas que pueden crear datos temporales o incrementar
el contador. make deploy y make install-* aplican cambios efectivos.
La migración requiere sudo bash SERVER/shared/unify.sh --apply y una
sesión administrativa abierta; no se ejecuta con git pull.
