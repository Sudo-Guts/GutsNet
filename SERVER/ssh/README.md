# GutsNet: usuario SSH restringido

La cuenta **gutsjail** administra documentos y carpetas dentro de
**/compartido**, con una consola en C y un chroot de OpenSSH. Es independiente
de la cuenta administradora **guts**.

## Instalar o actualizar

Desde la rama que contiene estos cambios:

```bash
cd ~/GutsNet
git pull --ff-only
make install-ssh
sudo passwd gutsjail
make check-ssh
```

`passwd` establece la contraseña de la cuenta; si ya tiene una que quieres
conservar, omite ese comando. La reinstalación conserva la contraseña existente
y los documentos compartidos.

El servidor necesita OpenSSH activo, GCC con soporte de enlace estático,
binutils y util-linux. El instalador revisa los requisitos antes de modificar
SSH. Prepara el grupo `gutsnet-files` y el área de intercambio si faltan; no es
necesario configurar FTPS primero.
Instala `acl` si falta y corrige la ACL de grupo y su herencia en el intercambio,
conservando las entradas con nombre y los archivos existentes.

## Conectarse desde el mismo Ubuntu

```bash
ssh gutsjail@127.0.0.1
```

Para conectarse desde la red, sustituye `127.0.0.1` por la IP actual del
servidor. Dentro de la sesión puedes probar:

```text
pwd
mkdir documentos
cd documentos
write nota.txt Este documento esta dentro del Jail.
cat nota.txt
touch vacio.txt
ls
rm vacio.txt
rm nota.txt
cd ..
rmdir documentos
exit
```

`exit` cierra la conexión SSH. En una sesión nueva siempre se empieza en
`/compartido`.

## Comandos de la consola

| Comando | Función |
| --- | --- |
| `help` | Muestra los comandos disponibles. |
| `pwd` | Muestra la ubicación dentro de /compartido. |
| `ls [ruta]` | Lista archivos y carpetas. |
| `cd [ruta]` | Entra en una subcarpeta; sin ruta vuelve a /compartido. |
| `mkdir carpeta` | Crea una carpeta. |
| `touch archivo.txt` | Crea un archivo vacío; conserva el contenido si ya existe. |
| `write archivo.txt texto` | Crea un documento con texto y un salto de línea. Rechaza nombres existentes. |
| `cat archivo.txt` | Lee un archivo regular de hasta 1 MiB. |
| `rm archivo.txt` | Elimina un archivo o el enlace indicado, sin seguirlo. |
| `rmdir carpeta` | Elimina una carpeta vacía. |
| `rm -r carpeta` | Elimina una carpeta y su contenido, sin seguir enlaces. |
| `exit` | Cierra la sesión. |

Se admiten rutas relativas y rutas que comiencen con `/compartido/`.
Los nombres admiten UTF-8, acentos y espacios. Usa comillas cuando el nombre
contenga espacios o signos que la consola reserva: `rm "Mi canción.mp3"`.
También admite comillas simples y escapes; nunca expande variables ni ejecuta
programas. Rechaza nombres ocultos, controles y UTF-8 inválido. El texto de
`write` se guarda literalmente, incluidos sus espacios y acentos.

En la raíz compartida, `cd ..` se rechaza. Desde una subcarpeta, `cd ..`
solo permite volver hacia /compartido. Se rechazan rutas que salgan del área,
por ejemplo `cat /etc/passwd`, `cd /` o `touch ../../fuera.txt`.
La consola no ejecuta `bash`, `sh`, `sudo`, programas subidos ni comandos
arbitrarios. Los errores devuelven un estado distinto de cero también al usar
`ssh gutsjail@servidor 'comando'`.

## Área compartida y permisos

| Ruta del servidor | Uso y permisos |
| --- | --- |
| `/home/gutsnet-jail` | Raíz del chroot, root:root, 755. |
| `/home/gutsnet-jail/usr/local/bin/gutsnet-shell` | Consola estática propiedad de root. |
| `/home/gutsnet-shared/peliculas` | Almacenamiento canónico de Cinema/SSH/FTPS después de la migración, root:gutsnet-files, 2770. |
| `/home/gutsnet-jail/compartido` | Montaje bind de la biblioteca de Cinema. |

La cuenta no tiene UID 0 ni pertenece a grupos administrativos. La raíz de la
jaula y la consola permanecen protegidas. Las nuevas carpetas de la consola
heredan el grupo compartido y los archivos se crean con permisos 660.
Los cambios en /compartido también se reflejan en el intercambio FTPS, cuando
ese servicio esté configurado.

Antes de la migración, el instalador conserva el intercambio FTP anterior;
actualizar la consola no cambia por sí solo el origen del montaje.
Los archivos de Cinema son parte del directorio compartido después de aplicar
la migración; su staging temporal queda fuera del chroot. El aislamiento del
servidor proviene de `ChrootDirectory` y los permisos de Linux; la consola
añade el límite de navegación y operaciones a /compartido. Resuelve las rutas
desde un descriptor de esa carpeta y abre cada directorio sin seguir enlaces.

## Subir y descargar archivos con SFTP

```bash
sftp gutsjail@127.0.0.1
```

```text
put informe.pdf /compartido/informe.pdf
get /compartido/informe.pdf informe-descargado.pdf
mkdir /compartido/respaldo
rm /compartido/informe.pdf
rmdir /compartido/respaldo
bye
```

SFTP usa `internal-sftp` dentro del mismo chroot. La raíz que pueda mostrar
el cliente corresponde a la jaula, no a la raíz del servidor; solo el área
compartida tiene permisos de escritura para esta cuenta.
SFTP y FTP(S) son servicios distintos.

## Comprobaciones

```bash
make check-ssh
make test-ssh
```

La primera revisión comprueba la cuenta, el montaje, la escritura en el área,
la protección de la raíz y las opciones efectivas de OpenSSH.
La segunda crea una jaula temporal y ejecuta 16 pruebas con un UID sin
privilegios: altas, bajas, navegación, grupo compartido, enlaces, rutas de
escape, comandos prohibidos y entradas largas. Solo utiliza sus propios
archivos temporales.

GitHub Actions también instala el módulo y comprueba conexiones reales por
SSH/SFTP en loopback, rechazos de escape y reinstalación con conservación de
documentos y contraseña.

El instalador respalda `/etc/ssh/sshd_config` y `/etc/fstab`, valida
`sshd -t` y las opciones para `gutsjail` y `guts`, y recarga SSH después
de validar. Restaura la configuración SSH si falla la validación o la recarga.

Para diagnóstico:

```bash
sudo journalctl -u ssh -n 50 --no-pager
sudo /usr/sbin/sshd -t
sudo /usr/sbin/sshd -T -C user=gutsjail,host=localhost,addr=127.0.0.1
```

Referencia: [ChrootDirectory de OpenSSH](https://man.openbsd.org/sshd_config#ChrootDirectory).

## Biblioteca única

`/compartido` utiliza un bind mount de `/home/gutsnet-shared/peliculas`.
La misma cuenta `gutsjail` puede administrar archivos de Cinema desde la
consola limitada o con SFTP, y usar FTPS mediante la contraseña de Linux.
El acceso web usa una contraseña Apache independiente. La migración exige
que se hayan terminado las sesiones activas y conserva los archivos originales
[según la guía](../shared/README.md). No reinstales SSH antes de migrar el
montaje antiguo, porque ahora el instalador comprueba la fuente canónica.
