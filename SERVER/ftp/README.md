# GutsNet — FTP seguro (vsftpd)

Configuracion preparada para FTPS explicito (FTP sobre TLS, TCP 21).
NO se instala ni inicia al actualizar el repositorio. Requiere
instalacion manual posterior en Ubuntu Server.

## Arquitectura y permisos

| Directorio | Dueno:grupo / permisos | Funcion |
| --- | --- | --- |
| /home/gutsnet-shared | Existente; sin modificaciones | Base del proyecto |
| /home/gutsnet-shared/peliculas | root:www-data / 750 | Cinema; fuera del FTPS |
| /home/gutsnet-shared/ftp | root:root / 755 | Raiz del chroot FTP, sin escritura |
| /home/gutsnet-shared/ftp/intercambio | root:gutsnet-files / 2770 | Subida y descarga |

- Usuario FTP: gutsftp, sin sudo, shell /usr/sbin/nologin.
- Autenticacion PAM dedicada: /etc/pam.d/gutsnet-vsftpd; no se modifica
  la politica PAM global ni /etc/shells.
- Acceso de usuarios por lista blanca; no hay FTP anonimo.
- Grupo gutsnet-files reservado para compartir archivos con el futuro
  usuario SSH restringido; NO tiene acceso a peliculas.
- Conexiones FTPS explicitamente cifradas con TLS 1.2/1.3, incluyendo datos.
- Puerto TCP 21 y modo pasivo TCP 40000 a 40010.
- Reutiliza el certificado HTTPS ya existente en
  /etc/ssl/certs/gutsnet.crt y su llave privada en
  /etc/ssl/private/gutsnet.key. La llave NO se publica en Git.

FTPS y SFTP son protocolos diferentes. Este modulo configura FTPS;
el modulo SSH se prepara de forma independiente.

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

El instalador NO modifica /home/gutsnet-shared/peliculas, Apache ni SSH.
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
- Usuario: gutsftp; contraseña: la establecida con passwd.
- Carpeta remota: /intercambio.

El certificado es autofirmado; verificarlo y confiar en el certificado
de laboratorio de manera controlada. No desactivar la verificacion TLS.

Se deben demostrar cuatro operaciones: iniciar sesion, listar archivos,
subir un fichero y descargarlo verificando que conserva su contenido.
Comprobar tambien que no se puede escapar del chroot hacia peliculas.

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
