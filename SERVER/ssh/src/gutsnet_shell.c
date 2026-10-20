/*
 * GutsNet - shell de comandos limitados dentro de OpenSSH ChrootDirectory.
 * No ejecuta un interprete ni programas externos. Sin acceso de escritura.
 * Archivos compartidos accesibles mediante SFTP (internal-sftp).
 */
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define LINE_MAX_BYTES 512U
#define MAX_CAT_BYTES (1024U * 1024U)
#define SHARED_PATH "/compartido"

static int safe_name(const char *name)
{
    if (name[0] == '\0' || name[0] == '.') return 0;
    for (const unsigned char *p = (const unsigned char *)name; *p; ++p) {
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' ||
              *p == '-')) return 0;
    }
    return 1;
}

static void show_help(void)
{
    puts("Comandos permitidos: help, pwd, ls, cat <archivo>, exit");
    puts("Subida y descarga: usar sftp con el mismo usuario.");
}

static void list_shared(void)
{
    DIR *dir = opendir(SHARED_PATH);
    if (!dir) { perror("ls"); return; }
    struct dirent *item;
    while ((item = readdir(dir)) != NULL) {
        if (safe_name(item->d_name)) puts(item->d_name);
    }
    closedir(dir);
}

static void cat_shared(const char *name)
{
    if (!safe_name(name)) {
        fputs("cat: nombre invalido (sin rutas ni archivos ocultos)\n", stderr);
        return;
    }
    int directory = open(SHARED_PATH, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) { perror("cat directorio"); return; }
    int fd = openat(directory, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    close(directory);
    if (fd < 0) { perror("cat archivo"); return; }
    struct stat st;
    if (fstat(fd, &st) < 0 || !S_ISREG(st.st_mode) || st.st_size > (off_t)MAX_CAT_BYTES) {
        fputs("cat: requiere archivo regular de hasta 1 MiB\n", stderr);
        close(fd);
        return;
    }
    char buffer[4096];
    size_t total = 0;
    for (;;) {
        ssize_t amount = read(fd, buffer, sizeof(buffer));
        if (amount == 0) break;
        if (amount < 0 && errno == EINTR) continue;
        if (amount < 0) { perror("cat read"); break; }
        if (total + (size_t)amount > MAX_CAT_BYTES) {
            fputs("cat: limite de 1 MiB excedido\n", stderr);
            break;
        }
        if (fwrite(buffer, 1, (size_t)amount, stdout) != (size_t)amount) {
            perror("cat write"); break;
        }
        total += (size_t)amount;
    }
    close(fd);
    fflush(stdout);
}

static int run_line(char *line)
{
    char *end = line + strlen(line);
    while (end > line && (end[-1] == '\n' || end[-1] == '\r' || end[-1] == ' ')) *--end = '\0';
    while (*line == ' ') ++line;
    if (*line == '\0') return 0;
    if (!strcmp(line, "help")) { show_help(); return 0; }
    if (!strcmp(line, "pwd")) { puts(SHARED_PATH); return 0; }
    if (!strcmp(line, "ls")) { list_shared(); return 0; }
    if (!strcmp(line, "exit")) return 1;
    if (!strncmp(line, "cat ", 4)) { cat_shared(line + 4); return 0; }
    fputs("Comando no permitido. Ejecuta help.\n", stderr);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc >= 2) {
        if (argc != 3 || strcmp(argv[1], "-c") != 0) {
            fputs("Uso no permitido.\n", stderr);
            return EXIT_FAILURE;
        }
        if (strlen(argv[2]) >= LINE_MAX_BYTES) {
            fputs("Comando demasiado largo.\n", stderr);
            return EXIT_FAILURE;
        }
        char line[LINE_MAX_BYTES];
        memcpy(line, argv[2], strlen(argv[2]) + 1);
        (void)run_line(line);
        return EXIT_SUCCESS;
    }
    puts("GutsNet SSH Jail - consola limitada");
    show_help();
    char line[LINE_MAX_BYTES];
    for (;;) {
        fputs("gutsnet-jail> ", stdout);
        fflush(stdout);
        if (fgets(line, sizeof(line), stdin) == NULL) break;
        if (strchr(line, '\n') == NULL && !feof(stdin)) {
            int ch;
            while ((ch = getchar()) != '\n' && ch != EOF) {}
            fputs("Comando demasiado largo.\n", stderr);
            continue;
        }
        if (run_line(line) != 0) break;
    }
    return EXIT_SUCCESS;
}
