/*
 * GutsNet - Echo TCP client (RFC 862)
 * Usage: echo_tcp_client <host> <port> <message>
 * Receives and prints bytes returned by the Echo server.
 */
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <netdb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define BUFFER_SIZE 4096

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

static int write_all(int fd, const unsigned char *buf, size_t len)
{
    size_t written = 0;
    while (written < len) {
        ssize_t count = write(fd, buf + written, len - written);
        if (count < 0) {
            if (errno == EINTR) {
                continue;
            }
            return -1;
        }
        if (count == 0) {
            return -1;
        }
        written += (size_t)count;
    }
    return 0;
}

int main(int argc, char *argv[])
{
    if (argc != 4) {
        fprintf(stderr, "Uso: %s <IP_o_host> <puerto> <mensaje>\n", argv[0]);
        return EXIT_FAILURE;
    }

    struct addrinfo hints = {0};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo *resolved = NULL;
    int rc = getaddrinfo(argv[1], argv[2], &hints, &resolved);
    if (rc != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rc));
        return EXIT_FAILURE;
    }

    int client_fd = -1;
    for (const struct addrinfo *addr = resolved; addr != NULL; addr = addr->ai_next) {
        client_fd = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
        if (client_fd < 0) {
            continue;
        }
        if (connect(client_fd, addr->ai_addr, addr->ai_addrlen) == 0) {
            break;
        }
        close(client_fd);
        client_fd = -1;
    }
    freeaddrinfo(resolved);

    if (client_fd < 0) {
        perror("connect");
        return EXIT_FAILURE;
    }

    const unsigned char *message = (const unsigned char *)argv[3];
    size_t message_size = strlen(argv[3]);
    if (send_all(client_fd, message, message_size) != 0) {
        perror("send");
        close(client_fd);
        return EXIT_FAILURE;
    }

    /* TCP half-close: stop sending; continue receiving the echo. */
    if (shutdown(client_fd, SHUT_WR) != 0) {
        perror("shutdown");
        close(client_fd);
        return EXIT_FAILURE;
    }

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
            close(client_fd);
            return EXIT_FAILURE;
        }
        if (write_all(STDOUT_FILENO, buffer, (size_t)received) != 0) {
            perror("write");
            close(client_fd);
            return EXIT_FAILURE;
        }
    }

    close(client_fd);
    return EXIT_SUCCESS;
}
