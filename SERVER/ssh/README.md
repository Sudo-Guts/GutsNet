# GutsNet - SSH Jail con consola restringida y SFTP

Modulo preparado para Ubuntu Server. NO se activa automaticamente al
actualizar Git. La instalacion se ejecutara cuando el servidor vuelva.

## Objetivo

- Mantener el usuario administrador guts sin cambios.
- Crear gutsjail, sin sudo, con autenticacion por contraseña.
- Aplicar ChrootDirectory /home/gutsnet-jail.
- Restringir comandos mediante una shell en C compilada estaticamente.
- Comandos admitidos: help, pwd, ls, cat archivo, exit.
- Habilitar SFTP mediante OpenSSH internal-sftp para subir y descargar.
- Compartir la carpeta FTPS:
  /home/gutsnet-shared/ftp/intercambio, montada en /compartido.
- Dejar /home/gutsnet-shared/peliculas fuera de la jaula.

FTP(S) y SFTP son protocolos diferentes. El primero usa vsftpd (TCP 21);
SSH y SFTP usan OpenSSH (TCP 22).

## Estructura

La shell compilada se instala en /usr/local/bin/gutsnet-shell tanto en el host
(para la validacion de OpenSSH) como dentro del chroot (para ejecutarse).

    /home/gutsnet-jail/                 root:root; 755
    |-- usr/local/bin/gutsnet-shell     root:root; 755; ELF estatico
    |-- dev/                            nodos basicos de dispositivo
    +-- compartido/                     bind mount del intercambio FTPS

La shell no interpreta cadenas arbitrarias ni ejecuta bash, sudo, sh o cd.
El comando cat admite nombres de archivo simples sin rutas ni symlinks,
limitando la lectura a un maximo de 1 MiB. Para cargar archivos se usa SFTP.

El limite del sistema de archivos proviene del chroot y de los permisos
Linux; la lista blanca de comandos complementa ese aislamiento.

## Instalar FTP primero

Este modulo requiere el grupo gutsnet-files y la ruta
/home/gutsnet-shared/ftp/intercambio. Ejecutar primero el instalador de FTPS,
revisar las comprobaciones y crear la contraseña de gutsftp.

## Instalacion diferida

Cuando vuelva el servidor:

    cd ~/GutsNet
    git pull --ff-only origin main

    sudo bash SERVER/ssh/install.sh --check

Mantener ABIERTA una conexion administrativa SSH independiente antes
de instalar y comprobar que funciona:

    sudo bash SERVER/ssh/install.sh --install
    sudo passwd gutsjail
    sudo bash SERVER/ssh/check.sh

El instalador crea una copia de /etc/ssh/sshd_config antes de editarlo.
Convierte el subsistema SFTP a internal-sftp para el chroot, agrega
Match User gutsjail al final, valida sshd -t y sshd -T -C para gutsjail
y guts y solo entonces recarga SSH. No reinicia SSH sin validar.

Registra un bind mount persistente en /etc/fstab, respaldando el archivo.
No cambia Apache, la biblioteca Cinema ni la propiedad de intercambio.

## Comprobar desde la computadora administradora

La IP 192.168.244.135 puede haber cambiado; confirmarla antes.

    ssh gutsjail@192.168.244.135

Dentro de la consola:

    help
    pwd
    ls
    cat prueba.txt
    exit

Un comando remoto que no esta permitido debe ser rechazado:

    ssh gutsjail@192.168.244.135 'uname -a'

Para subir y bajar archivos, usar SFTP:

    sftp gutsjail@192.168.244.135
    sftp> pwd
    sftp> put prueba.txt
    sftp> get prueba.txt prueba-descargada.txt
    sftp> bye

Debera ver /compartido; los mismos ficheros deben aparecer en
/intercambio al conectarse mediante FTPS. No debe poder navegar fuera
del chroot, ver peliculas, ejecutar sudo ni reenviar puertos.

## Recuperacion

Mantener abierta una terminal administrativa antes de probar.
El instalador restaura el archivo SSH anterior si falla la validacion.
Para diagnostico:

    sudo journalctl -u ssh -n 70 --no-pager
    sudo /usr/sbin/sshd -t
    sudo /usr/sbin/sshd -T -C user=gutsjail,host=localhost,addr=127.0.0.1

Las copias quedan en:

    /etc/ssh/sshd_config.gutsnet-backup-*
    /etc/fstab.gutsnet-backup-*

No registrar contraseñas o llaves privadas en Git.
