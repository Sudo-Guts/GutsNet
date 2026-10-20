# ============================================================
# GutsNet - Sockets (RFC 862 / RFC 867)
# ============================================================

CC       := gcc
CFLAGS   := -std=c11 -O2 -Wall -Wextra -Wpedantic
SRC_ECHO := src/echo
OUT      := out

.PHONY: all help echo-tcp echo-udp clean

all: echo-tcp echo-udp

help:
	@echo "make echo-tcp  - Compilar cliente y servidor Echo TCP"
	@echo "make echo-udp  - Compilar cliente y servidor Echo UDP"
	@echo "make clean     - Eliminar ejecutables generados"

echo-tcp: $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client

echo-udp: $(OUT)/echo_udp_server $(OUT)/echo_udp_client

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

clean:
	@rm -f $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client \
	       $(OUT)/echo_udp_server $(OUT)/echo_udp_client
