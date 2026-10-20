#!/usr/bin/env bash
# ============================================================
# GutsNet - Pruebas HTTP de la web publicada
# Uso: make test-web
# Variables opcionales: GUTSNET_URL y GUTSNET_HOST
# ============================================================

set -Eeuo pipefail

BASE_URL="${GUTSNET_URL:-http://127.0.0.1}"
HOST="${GUTSNET_HOST:-gutsnet.test}"
BASE_URL="${BASE_URL%/}"

command -v curl >/dev/null || { echo "ERROR: falta curl" >&2; exit 1; }
command -v php >/dev/null || { echo "ERROR: falta php-cli" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

ok() {
    printf 'OK: %s\n' "$*"
}

# Sin -f: necesitamos poder inspeccionar HTTP 405 en la API.
curl_opts=(
    --silent --show-error
    --connect-timeout 5 --max-time 30
    --header "Host: ${HOST}"
)

# Solicitud GET que descarga el contenido en un archivo temporal.
check_get() {
    local path="$1" mime_pattern="$2" file="$3"
    local info code mime

    info="$(curl "${curl_opts[@]}" -o "$tmp/$file" \
        -w '%{http_code} %{content_type}' "$BASE_URL$path")" \
        || fail "No se puede conectar a $path"

    code="${info%% *}"
    mime="${info#* }"

    [[ "$code" == "200" ]] || fail "$path devolvio HTTP $code (esperado 200)"
    [[ "$mime" =~ $mime_pattern ]] || fail "$path devolvio Content-Type: $mime"
    [[ -s "$tmp/$file" ]] || fail "$path devolvio un archivo vacio"

    ok "GET $path (HTTP $code; $mime)"
}

# Para audio bastan las cabeceras: evita descargar los MP3 completos.
check_head() {
    local path="$1" mime_pattern="$2"
    local info code mime

    info="$(curl "${curl_opts[@]}" --head -o /dev/null \
        -w '%{http_code} %{content_type}' "$BASE_URL$path")" \
        || fail "No se puede consultar $path"

    code="${info%% *}"
    mime="${info#* }"

    [[ "$code" == "200" ]] || fail "$path devolvio HTTP $code (esperado 200)"
    [[ "$mime" =~ $mime_pattern ]] || fail "$path devolvio Content-Type: $mime"

    ok "HEAD $path (HTTP $code; $mime)"
}

printf 'GutsNet: verificando %s (Host: %s)\n\n' "$BASE_URL" "$HOST"

check_get "/" '^text/html' "index.html"
check_get "/materias.html" '^text/html' "materias.html"
check_get "/assets/css/style.css" '^text/css' "style.css"
check_get "/assets/js/main.js" '^(application|text)/javascript' "main.js"

check_head "/assets/audio/ambiente1.mp3" '^audio/mpeg'
check_head "/assets/audio/ambiente2.mp3" '^audio/mpeg'

# Un navegador puede solicitar rangos del MP4 para posicionarse en el video.
info="$(curl "${curl_opts[@]}" --range 0-1023 -o "$tmp/video.bin" \
    -w '%{http_code} %{content_type}' \
    "$BASE_URL/assets/video/demostracion.mp4")" \
    || fail "No se puede descargar el video"

code="${info%% *}"
mime="${info#* }"
[[ "$code" == "206" ]] || fail "El video respondio HTTP $code (esperado 206 Partial Content)"
[[ "$mime" =~ ^video/mp4 ]] || fail "El video devolvio Content-Type: $mime"
[[ -s "$tmp/video.bin" ]] || fail "La respuesta del video esta vacia"
ok "GET video MP4 con Range (HTTP 206; $mime)"

# Solo POST debe incrementar las visitas; GET debe responder 405.
code="$(curl "${curl_opts[@]}" -o "$tmp/get-api.json" \
    -w '%{http_code}' "$BASE_URL/api/visitas.php")" \
    || fail "No se puede consultar la API"
[[ "$code" == "405" ]] || fail "GET /api/visitas.php devolvio $code (esperado 405)"
ok "GET /api/visitas.php (HTTP 405)"

read_counter() {
    local file="$1" code count
    code="$(curl "${curl_opts[@]}" --request POST \
        -o "$tmp/$file" -w '%{http_code}' \
        "$BASE_URL/api/visitas.php")" \
        || fail "POST al contador no pudo conectarse"

    [[ "$code" == "200" ]] || fail "POST al contador devolvio HTTP $code"

    count="$(php -r '
        $data = json_decode(file_get_contents("php://stdin"), true);
        if (!is_array($data) || !isset($data["visitas"]) ||
            !is_int($data["visitas"]) || $data["visitas"] < 0) {
            exit(1);
        }
        echo $data["visitas"];
    ' < "$tmp/$file")" || fail "El contador devolvio JSON invalido"

    printf '%s\n' "$count"
}

first="$(read_counter contador1.json)"
second="$(read_counter contador2.json)"

# Puede haber visitas concurrentes; por eso se verifica aumento, no +1 exacto.
(( second > first )) || fail "El contador no aumento ($first -> $second)"
ok "Contador persistente e incremental ($first -> $second)"

printf '\nTodas las comprobaciones HTTP finalizaron correctamente.\n'