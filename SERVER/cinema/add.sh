#!/usr/bin/env bash
# Importa audio o video sin sobrescribir otras ni publicar archivos privados en Git.
set -Eeuo pipefail
storage=/home/gutsnet-shared/peliculas
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$EUID" -eq 0 ]] || fail 'Ejecuta con sudo.'
[[ "$#" -ge 1 && "$#" -le 2 ]] || fail 'Uso: sudo bash SERVER/cinema/add.sh /ruta/video.mp4 [Nombre.mp4]'
source_file="$1"
name="${2:-$(basename -- "$source_file")}"
[[ -f "$source_file" && ! -L "$source_file" ]] || fail 'La fuente debe ser un archivo regular, no un enlace.'
[[ -d "$storage" && ! -L "$storage" && ! -L /home/gutsnet-shared ]] || fail 'Instala GutsCinema primero.'
[[ "$name" != */* && "$name" != .* && -n "$name" ]] || fail 'Nombre de destino no valido.'
case "${name,,}" in *.mp4|*.mp3|*.webm|*.ogv) ;; *) fail 'Formato permitido: MP4, MP3, WebM u OGV.' ;; esac
[[ ! -e "$storage/$name" && ! -L "$storage/$name" ]] || fail 'Ese nombre ya existe; elige otro para conservar el archivo anterior.'
install -o root -g www-data -m 640 -- "$source_file" "$storage/$name"
printf 'Importado: %s\nAbre https://gutsnet.test/cinema/\n' "$name"
