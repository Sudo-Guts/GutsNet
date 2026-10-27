# GutsNet

Servidor Linux para la materia Redes de Computadoras: sitio personal, multimedia,
transferencia de archivos, SSH y servicios de sockets desarrollados en C.

**Plataforma:** Ubuntu Server 26.04 LTS · Apache + PHP/SQLite · FTPS ·
OpenSSH/SFTP · Echo (RFC 862) y Daytime (RFC 867).

## Empezar en 30 segundos

Desde la raíz del repositorio:

```bash
make help                 # todos los comandos disponibles
make status               # consulta servicios; no instala nada
make test-sockets         # compila y prueba los clientes de red
make preview              # muestra cambios de la web sin publicarlos
```

Para actualizar el código de una instalación existente:

```bash
git status -sb
git pull --ff-only origin main
make status
```

**Importante:** `git pull` actualiza archivos del repositorio, **NO** reemplaza
configuraciones de Apache, instala servicios ni publica la web. Consulta
[Instalación](DOC/Instalacion.md) antes de actualizar servicios.

## ¿Dónde está cada cosa?

| Carpeta | Propósito |
| --- | --- |
| `C0DE/web/public/` | HTML, CSS, JavaScript, PHP público, música y video de demostración |
| `C0DE/sockets/` | 8 programas C: clientes y servidores Echo/Daytime TCP y UDP |
| `SERVER/apache/` | VirtualHosts HTTP/HTTPS |
| `SERVER/cinema/` | Instalación, almacenamiento privado y pruebas de GutsCinema |
| `SERVER/ftp/` | Configuración, instalación y verificación de FTPS |
| `SERVER/ssh/` | Usuario restringido, chroot, shell C y SFTP |
| `SERVER/sockets/` | Unidades systemd de Echo/Daytime |
| `scripts/` | Herramientas internas de pruebas y versiones de recursos |
| `DOC/` | Arquitectura, progreso, instalación y pruebas |

[Mapa completo y flujo entre servicios](DOC/Arquitectura.md).

## Qué funciona y qué se debe comprobar

Las conversaciones de prueba del **20 de octubre de 2026** confirmaron en el
servidor real: Apache, Cinema protegido, FTPS (subida/descarga), SSH Jail,
subida por SFTP, y servidores Echo/Daytime en los puertos oficiales TCP/UDP 7 y 13.

**No confundir el código disponible con su despliegue.** La actualización más
reciente de Cinema, SSH y la web está en GitHub; debe aplicarse y verificarse
explícitamente en Ubuntu antes de afirmarse que funciona allí.
Quedan como tareas de entrega el CV definitivo, pruebas entre dos equipos y
capturas de Wireshark. Véase [Checklist](DOC/CheckList.md).

## Comandos por subsistema

```bash
# Web: publicación con vista previa
make preview
make deploy                 # ADVERTENCIA: usa rsync --delete
make test-web

# Cinema (las pruebas solicitan las credenciales cuando corresponda)
make check-cinema
make test-cinema
make install-cinema         # cambio explícito en el servidor

# FTP y SSH
make check-ftp
make check-ssh
make install-ftp            # cambio explícito
make install-ssh            # cambio explícito

# Sockets
make test-sockets
make check-sockets
make install-sockets        # cambio explícito
```

**Seguridad:** `make deploy` sincroniza `C0DE/web/public/` hacia
`/var/www/gutsnet/public/` mediante `rsync --delete`.
No guardar películas privadas, bases de datos ni archivos manuales en ese
directorio publicado. No guardar contraseñas, certificados privados o bases de
datos en Git. Mantener SSH administrativo abierto durante cambios de SSH.

## Manuales

- [Arquitectura y dependencias](DOC/Arquitectura.md): cómo encajan los módulos.
- [Checklist real](DOC/CheckList.md): implementado, comprobado y pendiente.
- [Instalación segura](DOC/Instalacion.md): pasos separados por servicio.
- [Pruebas y evidencias](DOC/Pruebas.md): cómo demostrar cada requisito.
- [GutsCinema](SERVER/cinema/README.md) ·
  [FTPS](SERVER/ftp/README.md) ·
  [SSH Jail](SERVER/ssh/README.md) ·
  [Sockets](SERVER/sockets/README.md).

Los recursos del proyecto se mantienen en la red local salvo autorización
expresa para publicarlos fuera de ella.
