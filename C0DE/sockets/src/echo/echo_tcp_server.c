/*
 * GutsNet - Echo TCP server (RFC 862)
 * Default port: 7; use 7007 for unprivileged local tests.
 * Echoes bytes exactly, without assuming null-terminated strings.
 */
#define _POSIX_C_SOURCE 200809L

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define ECHO_PORT 7
#define BUFFER_SIZE 4096

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

static int send_all(int fd, const unsigned char *buf, size_t len)
{
    size_t sent = 0;

    while (sent < len) {
        ssize_t count = send(fd, buf + sent, len - sent, MSG_NOSIGNAL);
        if (count < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (count == 0) {
            return -1;
        }
        sent += (size_t)count;
    }
    return 0;
}

static void serve_client(int client_fd)
{
    unsigned char buffer[BUFFER_SIZE];

    for (;;) {
        ssize_t received = recv(client_fd, buffer, sizeof(buffer), 0);
        if (received == 0) {
            break;
        }
        if (received < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("recv");
            break;
        }
        if (send_all(client_fd, buffer, (size_t)received) != 0) {
            perror("send");
            break;
        }
    }
}

int main(int argc, char *argv[])
{
    uint16_t port = ECHO_PORT;
    if (argc > 2 || (argc == 2 && parse_port(argv[1], &port) != 0)) {
        fprintf(stderr, "Uso: %s [puerto: 1-65535]\n", argv[0]);
        return EXIT_FAILURE;
    }

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket");
        return EXIT_FAILURE;
    }

    int reuse = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) < 0) {
        perror("setsockopt");
        close(server_fd);
        return EXIT_FAILURE;
    }

    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(port);

    if (bind(server_fd, (const struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind");
        close(server_fd);
        return EXIT_FAILURE;
    }
    if (listen(server_fd, 16) < 0) {
        perror("listen");
        close(server_fd);
        return EXIT_FAILURE;
    }

    printf("GutsNet Echo TCP escuchando en 0.0.0.0:%u\n", (unsigned)port);
    fflush(stdout);

    for (;;) {
        struct sockaddr_in peer = {0};
        socklen_t peer_size = sizeof(peer);
        int client_fd = accept(server_fd, (struct sockaddr *)&peer, &peer_size);
        if (client_fd < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("accept");
            break;
        }

        char peer_ip[INET_ADDRSTRLEN] = {0};
        const char *ip = inet_ntop(AF_INET, &peer.sin_addr, peer_ip, sizeof(peer_ip));
        printf("Conexion: %s:%u\n", ip != NULL ? ip : "?", (unsigned)ntohs(peer.sin_port));
        fflush(stdout);

        serve_client(client_fd);
        close(client_fd);
    }

    close(server_fd);
    return EXIT_FAILURE;
}
