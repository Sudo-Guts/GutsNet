# ============================================================
# GutsNet - Sockets (RFC 862 / RFC 867)
# ============================================================

CC       := gcc
CFLAGS   := -std=c11 -O2 -Wall -Wextra -Wpedantic -Iinc
SRC_ECHO := src/echo
SRC_DAYTIME := src/daytime
OUT      := out

.PHONY: all help echo-tcp echo-udp daytime daytime-tcp daytime-udp clean

all: echo-tcp echo-udp daytime

help:
	@echo "make echo-tcp  - Compilar cliente y servidor Echo TCP"
	@echo "make echo-udp  - Compilar cliente y servidor Echo UDP"
	@echo "make daytime   - Compilar clientes y servidores Daytime TCP/UDP"
	@echo "make clean     - Eliminar ejecutables generados"

echo-tcp: $(OUT)/echo_tcp_server $(OUT)/echo_tcp_client

echo-udp: $(OUT)/echo_udp_server $(OUT)/echo_udp_client \
	       $(OUT)/daytime_tcp_server $(OUT)/daytime_tcp_client \
	       $(OUT)/daytime_udp_server $(OUT)/daytime_udp_client

daytime: daytime-tcp daytime-udp

daytime-tcp: $(OUT)/daytime_tcp_server $(OUT)/daytime_tcp_client

daytime-udp: $(OUT)/daytime_udp_server $(OUT)/daytime_udp_client

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
	       $(OUT)/echo_udp_server $(OUT)/echo_udp_client
