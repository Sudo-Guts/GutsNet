# Arquitectura de GutsNet

**Objetivo:** que cada servicio sea identificable, instalable y comprobable
sin conocer todos los demás. El repositorio contiene **código y plantillas**;
Ubuntu conserva **credenciales, datos y procesos** fuera de Git.

## Mapa de los servicios

```text
                    RED LOCAL (LAN)
                           |
                +----------+-----------+
                | Ubuntu Server GutsNet|
                |                      |
   TCP 80/443 --+ Apache / PHP / SQLite+-- /var/lib/gutsnet/ (contador)
                |          |           |
                |      GutsCinema -----+-- /home/gutsnet-shared/peliculas/
                |                      |
     TCP 21 ----+ FTPS / vsftpd --------+-- /home/gutsnet-shared/ftp/intercambio/
                |                      |                 ^
     TCP 22 ----+ SSH admin (guts)      |                 |
                | SSH Jail (gutsjail) --+-- /home/gutsnet-jail/compartido/
                |                              (bind mount)
  TCP/UDP 7 ----+ Echo RFC 862         |
  TCP/UDP 13 ---+ Daytime RFC 867      |
                +----------------------+
```

**FTP y SSH Jail** comparten solamente el área `intercambio`.
**Cinema** utiliza almacenamiento privado distinto; **el contador** tiene
almacenamiento persistente independiente. Los archivos publicados por Apache
no incluyen esos directorios.

## Dos capas distintas

### 1. Archivos versionados: repositorio Git

- `C0DE/web/public/`: recursos web y la aplicación PHP que sirve Apache.
- `C0DE/sockets/src/`: implementaciones de Echo y Daytime en C.
- `SERVER/`: configuración, instaladores y verificadores para Ubuntu.
- `scripts/`: validaciones internas de la web; no son servicios residentes.
- `.github/workflows/`: pruebas automáticas en GitHub Actions.
- `DOC/`: manuales y evidencias.

### 2. Estado real: Ubuntu Server

| Ruta o proceso | Función |
| --- | --- |
| `/var/www/gutsnet/public/` | Sitio desplegado desde el repositorio |
| `/var/lib/gutsnet/visitas.sqlite` | Contador de visitas persistente |
| `/home/gutsnet-shared/peliculas/` | Biblioteca privada de Cinema |
| `/home/gutsnet-shared/ftp/intercambio/` | Archivos de FTP/SFTP |
| `/home/gutsnet-jail/` | Raíz del chroot del usuario restringido |
| `/usr/local/libexec/gutsnet/` | Ejecutables systemd de Echo/Daytime |
| `/etc/apache2/`, `/etc/ssh/`, `/etc/vsftpd.conf` | Configuraciones activas |
| `/etc/gutsnet/` y `/etc/ssl/private/` | Credenciales y material privado |

Modificar un archivo de Git **no modifica automáticamente** su copia activa
en `/etc` o `/var/www`. Esta separación evita cambios sorpresa,
pero exige despliegues explícitos.

## Interfaces de red y protocolos

| Componente | Puerto habitual | Protocolo |
| --- | --- | --- |
| Sitio público | 80 | HTTP/TCP |
| Cinema privado | 443 | HTTPS/TCP |
| FTPS explícito | 21 y 40000–40010 | FTP + TLS/TCP |
| SSH administrativo, Jail y SFTP | 22 | SSH/TCP |
| Echo | 7 | TCP y UDP |
| Daytime | 13 | TCP y UDP |

El acceso remoto debe verificarse desde otro equipo de la **misma LAN**;
usar la IP del propio servidor desde el servidor mismo produce una ruta
`local ... dev lo` y no prueba conectividad entre equipos.

## Orden de dependencia recomendado

1. Red e IP del servidor, Ubuntu y SSH administrativo.
2. Apache, PHP, SQLite y sitio público.
3. HTTPS, Cinema y su almacenamiento privado.
4. FTPS y el directorio compartido.
5. SSH Jail, chroot y SFTP (intercambio compartido con FTPS).
6. Servidores Echo y Daytime mediante systemd.
7. Pruebas remotas y capturas Wireshark.

**Atención:** el instalador SSH más reciente puede preparar el área de
intercambio si falta, pero validar FTPS primero facilita el diagnóstico.

## Tres categorías de comandos

- **Consulta:** `make help`, `make status`,
  `make check-ftp`, `make check-ssh`,
  `make check-sockets`, `make check-cinema`.
- **Pruebas:** `make test-web`, `make test-sockets`,
  `make test-ssh`, `make test-cinema`; algunas modifican
  datos de prueba (como el contador) y necesitan un servicio activo.
- **Cambios efectivos:** `make deploy` y los objetivos
  `make install-*`; requieren revisar el sistema y sus respaldos.

## Simplificación deliberada

Se conservan las rutas `C0DE/`, `SERVER/` y `scripts/`
para no romper rutas absolutas, Makefiles y pruebas existentes.
La reestructuración comienza por **claridad, navegación y comandos coherentes**;
no borra scripts de seguridad o pruebas solo porque sean numerosos.
