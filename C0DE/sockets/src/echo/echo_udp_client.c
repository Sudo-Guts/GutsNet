/*
 * GutsNet - Echo UDP client (RFC 862)
 * Usage: echo_udp_client <host> <port> <message>
 * Sends one datagram and checks that the reply is identical.
 */
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define MAX_UDP_PAYLOAD 65507U
#define BUFFER_SIZE 65535U

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

    const unsigned char *message = (const unsigned char *)argv[3];
    size_t length = strlen(argv[3]);
    if (length > MAX_UDP_PAYLOAD) {
        fprintf(stderr, "Mensaje demasiado largo para UDP IPv4 (maximo %u bytes)\n",
                MAX_UDP_PAYLOAD);
        return EXIT_FAILURE;
    }

    struct addrinfo hints = {0};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;

    struct addrinfo *resolved = NULL;
    int rc = getaddrinfo(argv[1], argv[2], &hints, &resolved);
    if (rc != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(rc));
        return EXIT_FAILURE;
    }

    int fd = -1;
    for (const struct addrinfo *addr = resolved; addr != NULL; addr = addr->ai_next) {
        fd = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
        if (fd < 0) {
            continue;
        }
        if (connect(fd, addr->ai_addr, addr->ai_addrlen) == 0) {
            break;
        }
        close(fd);
        fd = -1;
    }
    freeaddrinfo(resolved);

    if (fd < 0) {
        perror("connect");
        return EXIT_FAILURE;
    }

    struct timeval timeout = {.tv_sec = 5, .tv_usec = 0};
    if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0) {
        perror("setsockopt");
        close(fd);
        return EXIT_FAILURE;
    }

    ssize_t sent;
    do {
        sent = send(fd, message, length, 0);
    } while (sent < 0 && errno == EINTR);
    if (sent < 0 || (size_t)sent != length) {
        perror("send");
        close(fd);
        return EXIT_FAILURE;
    }

    unsigned char buffer[BUFFER_SIZE];
    ssize_t received;
    do {
        received = recv(fd, buffer, sizeof(buffer), 0);
    } while (received < 0 && errno == EINTR);
    if (received < 0) {
        perror("recv (sin respuesta UDP)");
        close(fd);
        return EXIT_FAILURE;
    }

    if ((size_t)received != length || memcmp(buffer, message, length) != 0) {
        fprintf(stderr, "ERROR: el eco recibido no coincide con el mensaje enviado\n");
        close(fd);
        return EXIT_FAILURE;
    }

    if (write_all(STDOUT_FILENO, buffer, (size_t)received) != 0) {
        perror("write");
        close(fd);
        return EXIT_FAILURE;
    }

    close(fd);
    return EXIT_SUCCESS;
}
