/* GutsNet - Servidor Daytime TCP (RFC 867). Puerto 13 por defecto. */
#define _POSIX_C_SOURCE 200809L
#include "daytime.h"
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#define DAYTIME_PORT 13U

static int parse_port(const char *text, uint16_t *port)
{
    char *end = NULL;
    errno = 0;
    unsigned long value = strtoul(text, &end, 10);
    if (errno != 0 || text == end || *end != '\0' || value == 0 || value > 65535UL) {
        return -1;
    }
    *port = (uint16_t)value;
    return 0;
}

static int send_all(int fd, const char *data, size_t size)
{
    size_t sent = 0;
    while (sent < size) {
        ssize_t count = send(fd, data + sent, size - sent, MSG_NOSIGNAL);
        if (count < 0 && errno == EINTR) {
            continue;
        }
        if (count <= 0) {
            return -1;
        }
        sent += (size_t)count;
    }
    return 0;
}

int main(int argc, char *argv[])
{
    uint16_t port = DAYTIME_PORT;
    if (argc > 2 || (argc == 2 && parse_port(argv[1], &port) != 0)) {
        fprintf(stderr, "Uso: %s [puerto: 1-65535]\n", argv[0]);
        return EXIT_FAILURE;
    }
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) {
        perror("socket");
        return EXIT_FAILURE;
    }
    int reuse = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) != 0) {
        perror("setsockopt");
        close(fd);
        return EXIT_FAILURE;
    }
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(port);
    if (bind(fd, (const struct sockaddr *)&address, sizeof(address)) != 0) {
        perror("bind");
        close(fd);
        return EXIT_FAILURE;
    }
    if (listen(fd, 16) != 0) {
        perror("listen");
        close(fd);
        return EXIT_FAILURE;
    }
    printf("GutsNet Daytime TCP escuchando en 0.0.0.0:%u\n", (unsigned)port);
    fflush(stdout);
    for (;;) {
        int client = accept(fd, NULL, NULL);
        if (client < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("accept");
            break;
        }
        char datetime[64];
        size_t bytes = daytime_format(datetime, sizeof(datetime));
        if (bytes == 0 || send_all(client, datetime, bytes) != 0) {
            fprintf(stderr, "No se pudo enviar la respuesta Daytime TCP\n");
        }
        close(client);
    }
    close(fd);
    return EXIT_FAILURE;
}
