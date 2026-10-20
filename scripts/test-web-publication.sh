#!/usr/bin/env bash
# Prueba HTTP del despliegue: debe rechazar HTML, CSS o JS desactualizados.
# El servidor PHP es temporal y no modifica Apache ni archivos de producción.
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_DIR="$REPO_ROOT/C0DE/web/public"
command -v php >/dev/null || { echo "ERROR: falta php-cli" >&2; exit 1; }
command -v curl >/dev/null || { echo "ERROR: falta curl" >&2; exit 1; }

tmp="$(mktemp -d)"
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$tmp"
}
trap cleanup EXIT
mkdir "$tmp/public"
cp -R "$PUBLIC_DIR/." "$tmp/public/"

php -S 127.0.0.1:18085 -t "$tmp/public" > "$tmp/server.log" 2>&1 &
server_pid=$!
ready=0
for _ in {1..30}; do
    if curl -fsS --max-time 1 http://127.0.0.1:18085/ -o /dev/null 2>/dev/null; then
        ready=1
        break
    fi
    sleep 0.1
done
[[ "$ready" == 1 ]] || { cat "$tmp/server.log" >&2; exit 1; }

run_check() {
    GUTSNET_URL=http://127.0.0.1:18085 GUTSNET_ASSETS_ONLY=1 \
        bash "$REPO_ROOT/scripts/test-web.sh"
}

run_check
for relative in "index.html" "assets/css/style.css" "assets/js/main.js"; do
    printf '\n/* simular una version publicada distinta */\n' >> "$tmp/public/$relative"
    if run_check > "$tmp/result.log" 2>&1; then
        echo "ERROR: no se detecto el recurso desactualizado: $relative" >&2
        exit 1
    fi
    result="$(< "$tmp/result.log")"
    [[ "$result" == *"Apache sirve otra version de $relative."* ]] || {
        cat "$tmp/result.log" >&2
        exit 1
    }
    printf 'OK: se rechaza una version desactualizada de %s, aunque responda HTTP 200.\n' "$relative"
    cp "$PUBLIC_DIR/$relative" "$tmp/public/$relative"
done
