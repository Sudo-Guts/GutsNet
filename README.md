# GutsNet

Proyecto académico de administración de servidores,
desarrollo web y programación de sockets en Linux.

## Sistema
- Ubuntu 26.04 LTS
- Apache HTTP Server
- FTP mediante vsftpd
- OpenSSH
- Lenguaje C
- HTML, CSS, JavaScript y PHP

## Servicios

### Web
Página personal con CV, materias, proyectos y multimedia.

Incluye una biblioteca privada de películas con
autenticación y un contador persistente de visitas.

### FTP
Transferencia de archivos mediante cuentas autorizadas
y almacenamiento compartido.

### SSH
Acceso administrativo y un usuario restringido mediante
una Jail basada en chroot.

### Sockets
Implementación de clientes y servidores en C:

- Echo: RFC 862, TCP/UDP, puerto 7.
- Daytime: RFC 867, TCP/UDP, puerto 13.

## Organización

- C0DE/web: desarrollo de la página web.
- C0DE/sockets: programación de sockets.
- DOC: documentación y pruebas.
- SERVER: configuración de los servicios.

## Almacenamiento

Los archivos multimedia privados y el entorno chroot
se almacenarán fuera del repositorio, en la partición
/home.

## Seguridad

- Usuarios sin privilegios administrativos innecesarios.
- Acceso restringido a archivos compartidos.
- Autenticación para la biblioteca multimedia.
- Protección de credenciales y archivos privados.
