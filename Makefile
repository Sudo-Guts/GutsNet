# ============================================================
# GutsNet - Makefile
# ============================================================

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SRC := $(ROOT)/C0DE/web/public
DST := /var/www/gutsnet/public

HOST := gutsnet.test

RSYNC_FLAGS := -rpt --delete --delete-excluded --no-links \
               --chown=root:www-data --chmod=D755,F644 \
               --exclude=.gitkeep \
               --exclude=.env \
               --exclude=.env.* \
               --exclude=.htpasswd \
               --exclude=*.db \
               --exclude=*.sqlite \
               --exclude=*.sqlite3 \
               --exclude=*.sqlite-* \
               --exclude=*.htpasswd \
               --exclude=*.key \
               --exclude=*.pem \
               --exclude=*.p12 \
               --exclude=*.pfx

.PHONY: help check preview deploy test test-web

# ============================================================
# Help
# ============================================================

help:
	@echo "GutsNet - Comandos disponibles"
	@echo ""
	@echo "  make preview  - Mostrar cambios"
	@echo "  make deploy   - Publicar sitio web"
	@echo "  make test     - Comprobar Apache"
	@echo "  make test-web - Verificar HTML, CSS, JS, audio, video y contador"

# ============================================================
# Validation
# ============================================================

check:
	@command -v rsync >/dev/null || { echo "Falta rsync"; exit 1; }
	@test -d "$(SRC)" || { echo "No existe $(SRC)"; exit 1; }
	@[ -f "$(SRC)/index.html" ] || [ -f "$(SRC)/index.php" ] || { \
		echo "Falta index.html o index.php"; exit 1; \
	}
	@! mountpoint -q "$(DST)" || { echo "Destino montado"; exit 1; }
	@test ! -L "$(DST)" || { echo "Destino es enlace simbolico"; exit 1; }

# ============================================================
# Deployment
# ============================================================

preview: check
	@sudo rsync -nvi $(RSYNC_FLAGS) "$(SRC)/" "$(DST)/"

deploy: check
	@echo "Publicando GutsNet..."
	@sudo install -d -o root -g root -m 755 "$(DST)"
	@sudo rsync $(RSYNC_FLAGS) "$(SRC)/" "$(DST)/"
	@echo "GutsNet actualizado correctamente."

# ============================================================
# Tests
# ============================================================

test:
	@curl -fsS -o /dev/null \
		-w "HTTP %{http_code}\n" \
		-H "Host: $(HOST)" \
		http://127.0.0.1/

# ============================================================
# Comprehensive web tests (HTTP)
# ============================================================

test-web:
	@bash "$(ROOT)/scripts/test-web.sh"
