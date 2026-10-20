/* GutsNet - Servidor Daytime UDP (RFC 867). Puerto 13 por defecto. */
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

int main(int argc, char *argv[])
{
    uint16_t port = DAYTIME_PORT;
    if (argc > 2 || (argc == 2 && parse_port(argv[1], &port) != 0)) {
        fprintf(stderr, "Uso: %s [puerto: 1-65535]\n", argv[0]);
        return EXIT_FAILURE;
    }
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) {
        perror("socket");
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
    printf("GutsNet Daytime UDP escuchando en 0.0.0.0:%u\n", (unsigned)port);
    fflush(stdout);
    for (;;) {
        struct sockaddr_in peer = {0};
        socklen_t peer_length = sizeof(peer);
        char request[1];
        ssize_t received = recvfrom(fd, request, sizeof(request), 0,
                                    (struct sockaddr *)&peer, &peer_length);
        if (received < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("recvfrom");
            break;
        }
        char datetime[64];
        size_t bytes = daytime_format(datetime, sizeof(datetime));
        if (bytes == 0) {
            fprintf(stderr, "No se pudo obtener la fecha/hora UTC\n");
            continue;
        }
        ssize_t sent;
        do {
            sent = sendto(fd, datetime, bytes, 0,
                          (const struct sockaddr *)&peer, peer_length);
        } while (sent < 0 && errno == EINTR);
        if (sent < 0 || (size_t)sent != bytes) {
            perror("sendto");
        }
    }
    close(fd);
    return EXIT_FAILURE;
}
