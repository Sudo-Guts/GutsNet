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

.PHONY: help check preview deploy test test-web install-cinema check-cinema test-cinema install-ssh check-ssh test-ssh

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
	@echo "  make install-cinema - Configurar GutsCinema (pide sudo y contrasena de cine)"
	@echo "  make check-cinema   - Revisar HTTPS, Apache y acceso privado"
	@echo "  make test-cinema    - Probar el catalogo y la reproduccion con tu cuenta"
	@echo "  make install-ssh - Configurar la cuenta gutsjail y su area compartida"
	@echo "  make check-ssh   - Revisar aislamiento SSH y permisos de escritura"
	@echo "  make test-ssh    - Probar la consola en una jaula temporal"

# ============================================================
# Validation
# ============================================================

check:
	@command -v rsync >/dev/null || { echo "Falta rsync"; exit 1; }
	@command -v python3 >/dev/null || { echo "Falta python3"; exit 1; }
	@python3 "$(ROOT)/scripts/version-web-assets.py" --check
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

install-cinema:
	@sudo bash "$(ROOT)/SERVER/cinema/install.sh" --install

check-cinema:
	@sudo bash "$(ROOT)/SERVER/cinema/check.sh"

test-cinema:
	@bash "$(ROOT)/SERVER/cinema/test.sh"

install-ssh:
	@sudo bash "$(ROOT)/SERVER/ssh/install.sh" --install

check-ssh:
	@sudo bash "$(ROOT)/SERVER/ssh/check.sh"

test-ssh:
	@sudo $(MAKE) -C "$(ROOT)/SERVER/ssh" test-jail
