# GutsNet - Checklist

## Etapa 1. Proyecto
- [x] Definir requisitos.
- [x] Crear estructura de directorios.
- [x] Crear README.md.
- [x] Configurar .gitignore.
- [x] Crear checklist.
- [ ] Inicializar repositorio Git.

## Etapa 2. Apache
- [ ] Revisar configuración existente.
- [ ] Configurar VirtualHost.
- [ ] Crear página de inicio.
- [ ] Crear página personal.
- [ ] Agregar currículum.
- [ ] Agregar materias y proyectos.
- [ ] Integrar multimedia.
- [ ] Implementar contador de visitas.
- [ ] Comprobar acceso desde otra computadora.

## Etapa 3. Biblioteca multimedia
- [ ] Crear almacenamiento privado.
- [ ] Configurar autenticación web.
- [ ] Configurar HTTPS.
- [ ] Implementar catálogo de películas.
- [ ] Implementar reproductor de video.
- [ ] Proteger acceso directo a los archivos.

## Etapa 4. FTP
- [ ] Instalar vsftpd.
- [ ] Configurar usuario autorizado.
- [ ] Configurar directorio compartido.
- [ ] Configurar permisos.
- [ ] Habilitar transferencias cifradas.
- [ ] Probar subida y descarga.

## Etapa 5. SSH y Jail
- [ ] Verificar acceso administrativo.
- [ ] Crear usuario restringido.
- [ ] Construir entorno chroot.
- [ ] Configurar comandos permitidos.
- [ ] Integrar directorio compartido.
- [ ] Verificar ausencia de privilegios sudo.
- [ ] Probar aislamiento y transferencias.

## Etapa 6. Sockets en C
- [ ] Crear Makefile.
- [ ] Implementar Echo TCP.
- [ ] Implementar cliente Echo TCP.
- [ ] Implementar Echo UDP.
- [ ] Implementar cliente Echo UDP.
- [ ] Implementar Daytime TCP.
- [ ] Implementar cliente Daytime TCP.
- [ ] Implementar Daytime UDP.
- [ ] Implementar cliente Daytime UDP.
- [ ] Comprobar funcionamiento entre equipos.

## Etapa 7. Pruebas finales
- [ ] Comprobar servicios activos.
- [ ] Verificar permisos de usuarios.
- [ ] Comprobar seguridad de la biblioteca.
- [ ] Capturar tráfico con Wireshark.
- [ ] Documentar resultados.
- [ ] Preparar demostración.

## Estructuras
GutsNet/
├── .gitignore
├── README.md
│
├── C0DE/
│   ├── web/
│   │   ├── public/
│   │   │   ├── index.html
│   │   │   └── assets/
│   │   │       ├── css/
│   │   │       ├── js/
│   │   │       ├── img/
│   │   │       ├── audio/
│   │   │       └── video/
│   │   ├── app/
│   │   └── storage/
│   │
│   └── sockets/
│       ├── inc/
│       ├── src/
│       │   ├── echo/
│       │   └── daytime/
│       └── out/
│
├── DOC/
│   ├── CheckList.md
│   ├── Instalacion.md
│   └── Pruebas.md
│
└── SERVER/
    ├── apache/
    ├── ftp/
    ├── ssh/
    └── sockets/

/home/
├── guts/
│   └── GutsNet/             # Repositorio Git
│       ├── C0DE/
│       │   ├── web/
│       │   │   ├── public/
│       │   │   ├── app/
│       │   │   └── storage/
│       │   └── sockets/
│       ├── DOC/
│       └── SERVER/
│           ├── apache/
│           ├── ftp/
│           └── ssh/
│
├── gutsnet-jail/            # Raíz del chroot
│   ├── bin/
│   ├── lib/
│   ├── home/
│   └── compartido/          # Montaje de la carpeta común
│
└── gutsnet-shared/          # Almacenamiento real
    ├── peliculas/
    ├── documentos/
    └── archivos/
