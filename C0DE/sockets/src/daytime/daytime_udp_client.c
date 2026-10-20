/* GutsNet - Cliente Daytime UDP (RFC 867). */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
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

int main(int argc, char *argv[])
{
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "Uso: %s <IP_o_host> [puerto=13]\n", argv[0]);
        return EXIT_FAILURE;
    }
    const char *port = argc == 3 ? argv[2] : "13";
    struct addrinfo hints = {0};
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    struct addrinfo *resolved = NULL;
    int status = getaddrinfo(argv[1], port, &hints, &resolved);
    if (status != 0) {
        fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(status));
        return EXIT_FAILURE;
    }
    int fd = -1;
    for (struct addrinfo *addr = resolved; addr != NULL; addr = addr->ai_next) {
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
    char request = '?';
    if (send(fd, &request, sizeof(request), 0) != sizeof(request)) {
        perror("send");
        close(fd);
        return EXIT_FAILURE;
    }
    char buffer[256];
    ssize_t received;
    do {
        received = recv(fd, buffer, sizeof(buffer), 0);
    } while (received < 0 && errno == EINTR);
    if (received <= 0) {
        if (received < 0) {
            perror("recv");
        } else {
            fprintf(stderr, "Respuesta Daytime vacia\n");
        }
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
