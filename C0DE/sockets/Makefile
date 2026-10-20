# ============================================================
# GutsNet - Sockets (RFC 862 / RFC 867)
# ============================================================

CC       := gcc
CFLAGS   := -std=c11 -O2 -Wall -Wextra -Wpedantic
SRC_ECHO := src/echo
OUT      := out

.PHONY: all help echo-tcp clean

all: echo-tcp

help:
	@echo "make echo-tcp  - Compilar cliente y servidor Echo TCP"
	@echo "make clean     - Eliminar ejecutables generados"

echo-tcp: $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client

$(OUT):
	@mkdir -p $(OUT)

$(OUT)/echo_tcp_server: $(SRC_ECHO)/echo_tcp_server.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

$(OUT)/echo_tcp_client: $(SRC_ECHO)/echo_tcp_client.c | $(OUT)
	$(CC) $(CFLAGS) $< -o $@

clean:
	@rm -f $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client
