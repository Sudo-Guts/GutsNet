# ============================================================
# GutsNet - Sockets (RFC 862 / RFC 867)
# ============================================================

CC       := gcc
CFLAGS   := -std=c11 -O2 -Wall -Wextra -Wpedantic -Iinc
SRC_ECHO := src/echo
SRC_DAYTIME := src/daytime
OUT      := out

# Destinos externos. Se pueden cambiar al invocar make, sin editar el codigo C.
ECHO_HOST       ?= tcpbin.com
ECHO_PORT       ?= 4242
MESSAGE         ?= Hola desde GutsNet
DAYTIME_HOST    ?= time.nist.gov
DAYTIME_PORT    ?= 13
SOCKET_TIMEOUT  ?= 10s
export ECHO_HOST ECHO_PORT MESSAGE DAYTIME_HOST DAYTIME_PORT SOCKET_TIMEOUT

.PHONY: all help echo-tcp echo-udp daytime daytime-tcp daytime-udp echo-remoto hora-remota test clean

all: echo-tcp echo-udp daytime

help:
	@echo "make echo-tcp  - Compilar cliente y servidor Echo TCP"
	@echo "make echo-udp  - Compilar cliente y servidor Echo UDP"
	@echo "make daytime   - Compilar clientes y servidores Daytime TCP/UDP"
	@echo "make echo-remoto - Consultar Echo TCP externo (tcpbin.com:4242)"
	@echo "make hora-remota - Consultar Daytime TCP externo (time.nist.gov:13)"
	@echo "make test       - Probar clientes con servidores temporales, sin Internet"
	@echo "make clean     - Eliminar ejecutables generados"

echo-tcp: $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client

echo-udp: $(OUT)/echo_udp_server $(OUT)/echo_udp_client

daytime: daytime-tcp daytime-udp

daytime-tcp: $(OUT)/daytime_tcp_server $(OUT)/daytime_tcp_client

daytime-udp: $(OUT)/daytime_udp_server $(OUT)/daytime_udp_client

echo-remoto: $(OUT)/echo_tcp_client
	@printf 'Echo TCP externo: %s:%s\n' "$$ECHO_HOST" "$$ECHO_PORT"
	@timeout --foreground "$$SOCKET_TIMEOUT" $(OUT)/echo_tcp_client "$$ECHO_HOST" "$$ECHO_PORT" "$$MESSAGE" || \
	  { result=$$?; if [ "$$result" -eq 124 ]; then printf 'Sin respuesta de Echo antes del limite de espera.\n' >&2; fi; exit "$$result"; }
	@printf '\n'

hora-remota: $(OUT)/daytime_tcp_client
	@printf 'Daytime TCP externo: %s:%s\n' "$$DAYTIME_HOST" "$$DAYTIME_PORT"
	@timeout --foreground "$$SOCKET_TIMEOUT" $(OUT)/daytime_tcp_client "$$DAYTIME_HOST" "$$DAYTIME_PORT" || \
	  { result=$$?; if [ "$$result" -eq 124 ]; then printf 'Sin respuesta de Daytime antes del limite de espera.\n' >&2; fi; exit "$$result"; }

test: all
	python3 tests/test_clients.py

$(OUT):
	@mkdir -p $(OUT)

$(OUT)/echo_tcp_server: $(SRC_ECHO)/echo_tcp_server.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/echo_tcp_client: $(SRC_ECHO)/echo_tcp_client.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/echo_udp_server: $(SRC_ECHO)/echo_udp_server.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/echo_udp_client: $(SRC_ECHO)/echo_udp_client.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/daytime_tcp_server: $(SRC_DAYTIME)/daytime_tcp_server.c $(SRC_DAYTIME)/daytime_format.c inc/daytime.h | $(OUT)
	$(CC) $(CFLAGS) $(SRC_DAYTIME)/daytime_tcp_server.c $(SRC_DAYTIME)/daytime_format.c -o $@

$(OUT)/daytime_tcp_client: $(SRC_DAYTIME)/daytime_tcp_client.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/daytime_udp_server: $(SRC_DAYTIME)/daytime_udp_server.c $(SRC_DAYTIME)/daytime_format.c inc/daytime.h | $(OUT)
	$(CC) $(CFLAGS) $(SRC_DAYTIME)/daytime_udp_server.c $(SRC_DAYTIME)/daytime_format.c -o $@

$(OUT)/daytime_udp_client: $(SRC_DAYTIME)/daytime_udp_client.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

clean:
	@rm -f $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client \
	       $(OUT)/echo_udp_server $(OUT)/echo_udp_client \
	       $(OUT)/daytime_tcp_server $(OUT)/daytime_tcp_client \
	       $(OUT)/daytime_udp_server $(OUT)/daytime_udp_client
