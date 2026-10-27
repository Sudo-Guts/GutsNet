# GutsNet — FTP seguro (vsftpd)

Configuracion preparada para FTPS explicito (FTP sobre TLS, TCP 21).
NO se instala ni inicia al actualizar el repositorio. Requiere
instalacion manual posterior en Ubuntu Server.

## Arquitectura y permisos

| Directorio | Dueno:grupo / permisos | Funcion |
| --- | --- | --- |
| /home/gutsnet-shared | Existente; sin modificaciones | Base del proyecto |
| /home/gutsnet-shared/peliculas | root:gutsnet-files / 2770 tras migrar | Biblioteca canónica de Cinema, SSH/SFTP y FTPS |
| /home/gutsnet-shared/ftp | root:root / 755 | Raiz del chroot FTP, sin escritura |
| /home/gutsnet-shared/ftp/intercambio | root:gutsnet-files / 2770 | Subida y descarga |

- Usuario FTPS antes de la migración: gutsftp; después: gutsjail, la misma cuenta restringida de SSH.
- Autenticacion PAM dedicada: /etc/pam.d/gutsnet-vsftpd; no se modifica
  la politica PAM global ni /etc/shells.
- Acceso de usuarios por lista blanca; no hay FTP anonimo.
- Grupo gutsnet-files compartido con el usuario SSH restringido.
  Tras unificar, intercambia exactamente la misma biblioteca de Cinema.
- Conexiones FTPS explicitamente cifradas con TLS 1.2/1.3, incluyendo datos.
- Puerto TCP 21 y modo pasivo TCP 40000 a 40010.
- Reutiliza el certificado HTTPS ya existente en
  /etc/ssl/certs/gutsnet.crt y su llave privada en
  /etc/ssl/private/gutsnet.key. La llave NO se publica en Git.

FTPS y SFTP son protocolos diferentes. Este modulo configura FTPS;
el modulo SSH se prepara de forma independiente.

Para usar gutsjail, vsftpd necesita entrar al home Linux antes de aplicar
local_root. La migración y el instalador preparan `/compartido` en el host
como directorio vacío root:root 755. No es otro almacenamiento: dentro del
chroot FTP la biblioteca está en `/intercambio`, y dentro del jail SSH está
en `/compartido`. Si la ruta del host contiene datos ajenos, no se modifica.

## Instalacion diferida

Cuando el servidor vuelva a estar disponible, desde el repositorio:

    cd ~/GutsNet
    git pull --ff-only origin main

    # Preflight: solo verifica, sin cambios:
    sudo bash SERVER/ftp/install.sh --check

    # Tras revisar el resultado:
    sudo bash SERVER/ftp/install.sh --install

    # Definir la contraseña sin exponerla en el historial:
    sudo passwd gutsftp

    # Validar estado y directorios:
    sudo bash SERVER/ftp/check.sh

Antes de migrar, el instalador conserva la biblioteca separada de Cinema.
Después de migrar, /intercambio es un montaje de la biblioteca común; la
reinstalación conserva ese montaje y su contenido. No reconfigura Apache ni SSH.
Antes de reemplazar /etc/vsftpd.conf guarda una copia fechada
en /etc/vsftpd.conf.gutsnet-backup-... para restaurar si es necesario.
Si ya hay otra configuracion FTP en uso, revisa el impacto antes de
instalar. No se abren puertos de firewall automaticamente.

## Firewall y red

Si UFW esta activo, autorizar SOLO desde la subred o IP del laboratorio
los puertos 21/tcp y 40000:40010/tcp. No exponer FTPS a Internet
sin una evaluacion adicional. La IP LAN del servidor puede cambiar.

En servidores detras de NAT, se debe estudiar configurar pasv_address
y el reenvio del rango pasivo, segun la red efectiva.

## Prueba remota pendiente

Usar FileZilla u otro cliente FTPS desde la computadora administradora:

- Servidor: gutsnet.test, resuelto a la IP LAN del servidor.
- Protocolo: FTP; tipo de cifrado: FTP explicito sobre TLS.
- Puerto: 21; transferencia: pasiva.
- Usuario: gutsftp antes de unificar o gutsjail después; contraseña de la cuenta Linux.
- Carpeta remota: /intercambio.

El certificado es autofirmado; verificarlo y confiar en el certificado
de laboratorio de manera controlada. No desactivar la verificacion TLS.

Se deben demostrar cuatro operaciones: iniciar sesion, listar archivos,
subir un fichero y descargarlo verificando que conserva su contenido.
Comprobar que no se puede escapar del chroot; tras unificar, /intercambio muestra Cinema.

## Evidencias para la entrega

    sudo systemctl status vsftpd --no-pager
    sudo ss -lntp | grep ':21 '
    sudo ls -ld /home/gutsnet-shared/ftp{,/intercambio}
    sudo journalctl -u vsftpd -n 20 --no-pager

Filtro de Wireshark:

    tcp.port == 21 || (tcp.port >= 40000 && tcp.port <= 40010)

Debe apreciarse el establecimiento de la sesion y el trafico cifrado,
sin divulgar las contraseñas.

## Problemas comunes

- Error 530: comprobar la contraseña, la lista autorizada y el archivo
  /etc/pam.d/gutsnet-vsftpd. La politica dedicada acepta al usuario
  autorizado con shell nologin; la lista blanca sigue siendo obligatoria.
- Error de chroot escribible: /ftp debe ser root:root y no escribible;
  escribir solo en /intercambio.
- Login correcto sin listados: revisar firewall/rango pasivo,
  conectividad y TLS del canal de datos.
- Servicio fallido: journalctl -u vsftpd -n 50 --no-pager.
- Restauracion: copiar expresamente el respaldo de
  /etc/vsftpd.conf.gutsnet-backup-... a /etc/vsftpd.conf y
  reiniciar vsftpd, previa comprobacion de los cambios.

## Modo de biblioteca unificada

Después de ejecutar la migración documentada en [Biblioteca unificada](../shared/README.md),
FTPS autoriza únicamente a `gutsjail`, y `/intercambio` es un bind mount de
`/home/gutsnet-shared/peliculas`. El chroot de FTPS permanece en
`/home/gutsnet-shared/ftp`, propiedad root:root y no escribible por el usuario.
No se necesita una cuenta FTP separada. Conserva `gutsftp` deshabilitada hasta
comprobar todas las operaciones y revisar sus archivos anteriores.

El instalador reconoce el marcador privado `/etc/gutsnet/media-unificada`:
cuando existe, no vuelve a autorizar a `gutsftp`. No ejecutes `--install`
antes de migrar la biblioteca. Probar subida y descarga de MP3/MP4 con
`gutsjail` es parte de la validación funcional.
