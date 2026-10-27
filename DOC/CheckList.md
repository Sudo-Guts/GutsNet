# GutsNet — checklist de entrega

**Última revisión del estado conocido:** 22 de octubre de 2026.

**Convención:** comprobado = observado en el servidor durante las pruebas del
20 de octubre; disponible en Git = existe el código, pero puede necesitar
desplegarse otra vez; pendiente = falta evidencia o un entregable.

## Código y repositorio

- [x] Repositorio GitHub con rama principal `main`.
- [x] Estructura modular de web, sockets y servicios Linux.
- [x] Cliente y servidor Echo TCP/UDP en C.
- [x] Cliente y servidor Daytime TCP/UDP en C.
- [x] Makefile y scripts de instalación/verificación.
- [x] Integrar la rama `web/pastel-lab` en `main` (PR #2).
- [ ] Revisar en Ubuntu los cambios de web, Cinema y SSH incorporados en PR #2.
- [ ] Confirmar que no quedan cambios locales sin integrar o respaldar.

## Web y multimedia

- [x] Apache sirvió el sitio, páginas, audio y video en pruebas locales.
- [x] Contador PHP/SQLite incrementó las visitas en pruebas locales.
- [x] GutsCinema exigió autenticación y usó HTTPS en las pruebas iniciales.
- [x] Descarga parcial de multimedia de Cinema probada con HTTP 206.
- [x] Código de nueva interfaz y administración de Cinema fusionado en Git.
- [ ] Aplicar la actualización web/Cinema y repetir sus pruebas en Ubuntu.
- [ ] Agregar currículum (CV) definitivo.
- [ ] Capturar evidencias desde navegador de otro equipo.

## FTP y SSH

- [x] vsftpd activo con FTPS explícito y TLS.
- [x] Ingreso y listado de `gutsftp` probados localmente.
- [x] Subida, descarga e integridad de archivo FTPS comprobadas.
- [x] Usuario `gutsjail` autenticado en consola restringida.
- [x] Chroot y carpeta común verificados.
- [x] Un comando no permitido se rechazó en la consola.
- [x] SFTP subió un archivo sin cambios al almacenamiento compartido.
- [x] SSH administrativo permaneció activo tras instalar Jail.
- [ ] Probar descarga SFTP desde sesión remota.
- [ ] Aplicar/verificar las nuevas funciones de archivos del Jail (PR #2).
- [ ] Comprobar FTPS y SSH/SFTP desde otra computadora de la LAN.
- [ ] Revisar contraseñas y permisos antes de la demostración.

## Sockets y protocolos

- [x] Echo TCP y UDP responden en puerto 7.
- [x] Daytime TCP y UDP responden en puerto 13.
- [x] Las cuatro unidades systemd estaban activas y habilitadas.
- [x] Clientes locales recuperaron mensaje/fecha UTC.
- [ ] Probar clientes desde otra computadora: el último comando `ip route get`
      mostró `local ... dev lo` y por tanto aún no fue prueba remota.
- [ ] Guardar una captura Wireshark con intercambio TCP y UDP sobre la LAN.
- [ ] Verificar exposición solo en la red local o según requisitos del profesor.

## Evidencias y documentación

- [ ] Ejecutar `make status` y verificaciones individuales después de actualizar.
- [ ] Registrar las salidas finales de servicios y pruebas.
- [ ] Capturas del portafolio, contador, Cinema, FTP, SSH/SFTP y sockets.
- [ ] Revisar diseño responsivo y enlaces a proyectos.
- [ ] Preparar la demostración y completar el CV.

## Verificaciones rápidas

```bash
git status -sb
make help
make status
make check-ftp
make check-ssh
make check-sockets
make check-cinema
```

Consulta [Arquitectura](Arquitectura.md) para entender el flujo y
[Pruebas](Pruebas.md) para generar las evidencias.
