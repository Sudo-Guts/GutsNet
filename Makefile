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

.PHONY: help check preview deploy test test-web install-cinema check-cinema test-cinema install-ssh check-ssh test-ssh install-ftp check-ftp install-sockets check-sockets test-sockets status

# ============================================================
# Help
# ============================================================

help:
	@echo "GutsNet - comandos desde la raiz del repositorio"
	@echo ""
	@echo "  CONSULTAR (no modifica servicios)"
	@echo "  make status          Estado de Apache, FTP, SSH y sockets"
	@echo "  make check-ftp       Comprobar el servidor FTPS"
	@echo "  make check-ssh       Comprobar SSH Jail"
	@echo "  make check-sockets   Comprobar los puertos Echo y Daytime"
	@echo "  make check-cinema    Comprobar Cinema y HTTPS"
	@echo ""
	@echo "  DESARROLLO Y PRUEBAS"
	@echo "  make preview         Ver cambios web antes de publicarlos"
	@echo "  make test-web        Probar web, recursos y contador desplegados"
	@echo "  make test-cinema     Probar Cinema (requiere cuenta)"
	@echo "  make test-ssh        Probar la consola en chroot temporal"
	@echo "  make test-sockets    Compilar y probar clientes de sockets"
	@echo ""
	@echo "  INSTALACION / CAMBIOS EN EL SISTEMA"
	@echo "  make deploy          Publicar la web con rsync --delete"
	@echo "  make install-cinema  Instalar/actualizar Cinema"
	@echo "  make install-ftp     Instalar/actualizar FTPS"
	@echo "  make install-ssh     Instalar/actualizar SSH Jail"
	@echo "  make install-sockets Instalar/actualizar servicios Echo/Daytime"
	@echo ""
	@echo "  Guia inicial: README.md | Arquitectura: DOC/Arquitectura.md"

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

# ============================================================
# Servidores adicionales - acciones explicitas y separadas
# ============================================================

install-ftp:
	@sudo bash "$(ROOT)/SERVER/ftp/install.sh" --install

check-ftp:
	@sudo bash "$(ROOT)/SERVER/ftp/check.sh"

install-sockets:
	@sudo bash "$(ROOT)/SERVER/sockets/install.sh" --install

check-sockets:
	@bash "$(ROOT)/SERVER/sockets/check.sh"

test-sockets:
	@$(MAKE) -C "$(ROOT)/C0DE/sockets" test

# Solo consulta unidades; no hace cambios ni presupone que esten instaladas.
status:
	@echo "GutsNet - estado de servicios systemd"
	@for unit in apache2 vsftpd ssh \
	    gutsnet@echo_tcp_server.service gutsnet@echo_udp_server.service \
	    gutsnet@daytime_tcp_server.service gutsnet@daytime_udp_server.service; do \
	    printf "%-43s %s\\n" "$$unit" "$$(systemctl is-active "$$unit" 2>/dev/null || true)"; \
	done
	@echo "Puertos esperados: HTTP 80, HTTPS 443, FTPS 21 + 40000-40010, SSH 22, Echo 7, Daytime 13"
