/*
 * GutsNet - Echo UDP server (RFC 862)
 * Default UDP port: 7. Use 7007 for unprivileged tests.
 * Echoes each datagram exactly, including binary data.
 */
#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#define ECHO_PORT 7U
#define BUFFER_SIZE 65535U

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
    uint16_t port = ECHO_PORT;
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

    printf("GutsNet Echo UDP escuchando en 0.0.0.0:%u\n", (unsigned)port);
    fflush(stdout);

    unsigned char buffer[BUFFER_SIZE];
    for (;;) {
        struct sockaddr_in peer = {0};
        socklen_t peer_len = sizeof(peer);
        ssize_t received = recvfrom(fd, buffer, sizeof(buffer), 0,
                                    (struct sockaddr *)&peer, &peer_len);
        if (received < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("recvfrom");
            break;
        }

        ssize_t sent;
        do {
            sent = sendto(fd, buffer, (size_t)received, 0,
                          (const struct sockaddr *)&peer, peer_len);
        } while (sent < 0 && errno == EINTR);

        if (sent < 0 || sent != received) {
            perror("sendto");
            continue;
        }

        char peer_ip[INET_ADDRSTRLEN];
        const char *ip = inet_ntop(AF_INET, &peer.sin_addr, peer_ip, sizeof(peer_ip));
        printf("Eco UDP: %zd bytes a %s:%u\n", received,
               ip != NULL ? ip : "?", (unsigned)ntohs(peer.sin_port));
        fflush(stdout);
    }

    close(fd);
    return EXIT_FAILURE;
}
