/* GutsNet - Cliente Daytime TCP (RFC 867). */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

static int write_all(int fd, const char *buf, size_t length)
{
    size_t done = 0;
    while (done < length) {
        ssize_t n = write(fd, buf + done, length - done);
        if (n < 0 && errno == EINTR) {
            continue;
        }
        if (n <= 0) {
            return -1;
        }
        done += (size_t)n;
    }
    return 0;
}

static void print_destination(const struct addrinfo *addr)
{
    char host[128], port[32];
    if (getnameinfo(addr->ai_addr, addr->ai_addrlen, host, sizeof(host),
                    port, sizeof(port), NI_NUMERICHOST | NI_NUMERICSERV) == 0) {
        fprintf(stderr, "Daytime TCP -> %s%s%s:%s\n",
                addr->ai_family == AF_INET6 ? "[" : "", host,
                addr->ai_family == AF_INET6 ? "]" : "", port);
    }
}

/* 0: respuesta completa; 1: sin datos, probar otro peer; -1: error tras escribir. */
static int receive_daytime(int fd)
{
    char buffer[256];
    size_t total = 0;
    for (;;) {
        ssize_t received = recv(fd, buffer, sizeof(buffer), 0);
        if (received == 0) {
            if (total == 0) {
                fprintf(stderr, "Respuesta Daytime vacia en esta direccion\n");
                return 1;
            }
            return 0;
        }
        if (received < 0 && errno == EINTR) {
            continue;
        }
        if (received < 0) {
            perror("recv");
            return total == 0 ? 1 : -1;
        }
        if (write_all(STDOUT_FILENO, buffer, (size_t)received) != 0) {
            perror("write");
            return -1;
        }
        total += (size_t)received;
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Uso: %s <IP_o_host> [puerto=13]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const char *port = argc == 3 ? argv[2] : "13";
    struct addrinfo hints = {0};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *resolved = NULL;
    int status = getaddrinfo(argv[1], port, &hints, &resolved);
    if (status != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(status));
        return EXIT_FAILURE;
    }
    for (struct addrinfo *addr = resolved; addr != NULL; addr = addr->ai_next) {
        print_destination(addr);
        int fd = socket(addr->ai_family, addr->ai_socktype, addr->ai_protocol);
        if (fd < 0) {
            perror("socket");
            continue;
        }
        if (connect(fd, addr->ai_addr, addr->ai_addrlen) != 0) {
            perror("connect");
            close(fd);
            continue;
        }
        struct timeval timeout = {.tv_sec = 5, .tv_usec = 0};
        if (setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) != 0) {
            perror("setsockopt");
            close(fd);
            continue;
        }
        int response = receive_daytime(fd);
        close(fd);
        if (response <= 0) {
            /* Evita mezclar una respuesta parcial con los datos de otro servidor. */
            freeaddrinfo(resolved);
            return response == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
        }
    }
    freeaddrinfo(resolved);
    fprintf(stderr, "No se recibio Daytime de ninguna direccion de %s:%s\n",
            argv[1], port);
    return EXIT_FAILURE;
}
