/*
 * GutsNet: consola sin programas externos para OpenSSH ChrootDirectory.
 * Todas las operaciones se anclan a /compartido con openat y O_NOFOLLOW.
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

#define LINE_MAX_BYTES 4096U
#define PATH_MAX_BYTES 1024U
#define NAME_MAX_BYTES 255U
#define MAX_CAT_BYTES (1024U * 1024U)
#define MAX_REMOVE_DEPTH 64U
#define SHARED_PATH "/compartido"

static int shared_fd = -1;
static char current[PATH_MAX_BYTES] = "";

enum result { COMMAND_OK, COMMAND_ERROR, COMMAND_EXIT };

static int safe_name(const char *name)
{
    if (name[0] == '\0' || name[0] == '.' || strlen(name) > NAME_MAX_BYTES) return 0;
    for (const unsigned char *p = (const unsigned char *)name; *p; ++p) {
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') ||
              (*p >= '0' && *p <= '9') || *p == '.' || *p == '_' || *p == '-')) return 0;
    }
    return 1;
}

static void show_help(void)
{
    puts("Comandos: help, pwd, ls [ruta], cd [ruta], touch <archivo>,");
    puts("write <archivo> <texto>, cat <archivo>, mkdir <carpeta>,");
    puts("rm <archivo>, rmdir <carpeta-vacia>, rm -r <carpeta>, exit");
    puts("write crea un documento nuevo; el texto se guarda literalmente.");
    puts("Usa nombres sin espacios: letras, numeros, guion, punto y guion bajo.");
    puts("Solo puedes navegar y modificar /compartido y sus subcarpetas.");
    puts("Para subir o descargar documentos completos, usa SFTP.");
}

/* Normalizacion logica: .. nunca puede superar la raiz de /compartido. */
static int resolve_path(const char *argument, char resolved[PATH_MAX_BYTES])
{
    char copy[PATH_MAX_BYTES];
    if (strlen(argument) >= sizeof(copy)) { errno = ENAMETOOLONG; return -1; }
    if (argument[0] == '/') {
        size_t base = strlen(SHARED_PATH);
        if (strncmp(argument, SHARED_PATH, base) != 0 ||
            (argument[base] != '\0' && argument[base] != '/')) {
            errno = EPERM;
            return -1;
        }
        argument += base;
        resolved[0] = '\0';
    } else {
        memcpy(resolved, current, strlen(current) + 1);
    }
    memcpy(copy, argument, strlen(argument) + 1);
    char *save = NULL;
    for (char *part = strtok_r(copy, "/", &save); part; part = strtok_r(NULL, "/", &save)) {
        if (!strcmp(part, ".")) continue;
        if (!strcmp(part, "..")) {
            if (resolved[0] == '\0') { errno = EPERM; return -1; }
            char *slash = strrchr(resolved, '/');
            if (slash) *slash = '\0'; else resolved[0] = '\0';
            continue;
        }
        if (!safe_name(part)) { errno = EINVAL; return -1; }
        size_t used = strlen(resolved), length = strlen(part);
        if (used + (used != 0) + length >= PATH_MAX_BYTES) {
            errno = ENAMETOOLONG;
            return -1;
        }
        if (used) resolved[used++] = '/';
        memcpy(resolved + used, part, length + 1);
    }
    return 0;
}

/* Cada componente se abre por descriptor: ningun enlace redirige una operacion. */
static int open_directory(const char *relative)
{
    if (shared_fd < 0) {
        shared_fd = open(SHARED_PATH, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (shared_fd < 0) return -1;
    }
    int directory = openat(shared_fd, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return -1;
    char copy[PATH_MAX_BYTES];
    memcpy(copy, relative, strlen(relative) + 1);
    char *save = NULL;
    for (char *part = strtok_r(copy, "/", &save); part; part = strtok_r(NULL, "/", &save)) {
        int next = openat(directory, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        int saved = errno;
        close(directory);
        if (next < 0) { errno = saved; return -1; }
        directory = next;
    }
    return directory;
}

static int open_parent(const char *relative, char name[NAME_MAX_BYTES + 1])
{
    if (relative[0] == '\0') { errno = EPERM; return -1; }
    char parent[PATH_MAX_BYTES];
    memcpy(parent, relative, strlen(relative) + 1);
    char *slash = strrchr(parent, '/');
    const char *leaf = slash ? slash + 1 : parent;
    memcpy(name, leaf, strlen(leaf) + 1);
    if (slash) *slash = '\0'; else parent[0] = '\0';
    return open_directory(parent);
}

static int list_directory(const char *relative)
{
    int fd = open_directory(relative);
    if (fd < 0) return -1;
    DIR *directory = fdopendir(fd);
    if (!directory) { int saved = errno; close(fd); errno = saved; return -1; }
    int result = 0, saved = 0;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(directory);
        if (!entry) { if (errno) { result = -1; saved = errno; } break; }
        if (!safe_name(entry->d_name)) continue;
        struct stat st;
        if (fstatat(fd, entry->d_name, &st, AT_SYMLINK_NOFOLLOW) < 0) {
            result = -1; saved = errno; break;
        }
        printf("%s%s\n", entry->d_name, S_ISDIR(st.st_mode) ? "/" : "");
    }
    if (closedir(directory) < 0 && result == 0) { result = -1; saved = errno; }
    if (result < 0) errno = saved;
    return result;
}

static int cat_file(int parent, const char *name)
{
    int fd = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) return -1;
    struct stat st;
    if (fstat(fd, &st) < 0) { int saved = errno; close(fd); errno = saved; return -1; }
    if (!S_ISREG(st.st_mode) || st.st_size > (off_t)MAX_CAT_BYTES) {
        close(fd);
        fputs("cat: requiere archivo regular de hasta 1 MiB\n", stderr);
        errno = EINVAL;
        return -1;
    }
    char buffer[4096];
    size_t total = 0;
    int result = 0, saved = 0;
    for (;;) {
        ssize_t amount = read(fd, buffer, sizeof(buffer));
        if (amount == 0) break;
        if (amount < 0 && errno == EINTR) continue;
        if (amount < 0) { result = -1; saved = errno; break; }
        if (total + (size_t)amount > MAX_CAT_BYTES) {
            result = -1; saved = EFBIG; break;
        }
        if (fwrite(buffer, 1, (size_t)amount, stdout) != (size_t)amount) {
            result = -1; saved = EIO; break;
        }
        total += (size_t)amount;
    }
    if (close(fd) < 0 && result == 0) { result = -1; saved = errno; }
    if (fflush(stdout) != 0 && result == 0) { result = -1; saved = errno; }
    if (result < 0) errno = saved;
    return result;
}

static int create_file(int parent, const char *name, const char *text)
{
    int fd = openat(parent, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0660);
    if (fd < 0) {
        /* touch conserva un archivo existente; nunca sigue enlaces ni trunca. */
        if (!text && errno == EEXIST) {
            struct stat st;
            if (fstatat(parent, name, &st, AT_SYMLINK_NOFOLLOW) < 0) return -1;
            if (S_ISREG(st.st_mode)) return 0;
            errno = EINVAL;
        }
        return -1;
    }
    int result = 0, saved = 0;
    if (text) {
        size_t length = strlen(text), sent = 0;
        while (sent < length) {
            ssize_t amount = write(fd, text + sent, length - sent);
            if (amount < 0 && errno == EINTR) continue;
            if (amount <= 0) { result = -1; saved = amount < 0 ? errno : EIO; break; }
            sent += (size_t)amount;
        }
        if (result == 0) {
            ssize_t amount;
            do { amount = write(fd, "\n", 1); } while (amount < 0 && errno == EINTR);
            if (amount != 1) { result = -1; saved = amount < 0 ? errno : EIO; }
        }
    }
    if (close(fd) < 0 && result == 0) { result = -1; saved = errno; }
    if (result < 0) errno = saved;
    return result;
}

static int remove_tree(int parent, const char *name, unsigned int depth)
{
    struct stat before;
    if (fstatat(parent, name, &before, AT_SYMLINK_NOFOLLOW) < 0) return -1;
    if (!S_ISDIR(before.st_mode)) return unlinkat(parent, name, 0);
    if (depth >= MAX_REMOVE_DEPTH) { errno = ELOOP; return -1; }
    int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (fd < 0) return -1;
    if (fstat(fd, &before) < 0) { int saved = errno; close(fd); errno = saved; return -1; }
    DIR *directory = fdopendir(fd);
    if (!directory) { int saved = errno; close(fd); errno = saved; return -1; }
    int result = 0, saved = 0;
    for (;;) {
        errno = 0;
        struct dirent *entry = readdir(directory);
        if (!entry) { if (errno) { result = -1; saved = errno; } break; }
        if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
        if (remove_tree(fd, entry->d_name, depth + 1) < 0) {
            result = -1; saved = errno; break;
        }
    }
    if (closedir(directory) < 0 && result == 0) { result = -1; saved = errno; }
    if (result < 0) { errno = saved; return -1; }
    struct stat after;
    if (fstatat(parent, name, &after, AT_SYMLINK_NOFOLLOW) < 0) return -1;
    if (before.st_dev != after.st_dev || before.st_ino != after.st_ino) {
        errno = ESTALE;
        return -1;
    }
    return unlinkat(parent, name, AT_REMOVEDIR);
}

static char *next_word(char **cursor)
{
    *cursor += strspn(*cursor, " \t");
    if (**cursor == '\0') return NULL;
    char *word = *cursor;
    *cursor += strcspn(*cursor, " \t");
    if (**cursor != '\0') *(*cursor)++ = '\0';
    return word;
}

static enum result run_line(char *line)
{
    char *end = line + strlen(line);
    while (end > line && strchr("\r\n \t", end[-1])) *--end = '\0';
    char *cursor = line;
    char *command = next_word(&cursor);
    if (!command) return COMMAND_OK;
    char *argument = next_word(&cursor);
    if (!strcmp(command, "help") || !strcmp(command, "pwd") || !strcmp(command, "exit")) {
        if (argument) goto usage;
        if (!strcmp(command, "help")) show_help();
        else if (!strcmp(command, "pwd")) printf(SHARED_PATH "%s%s\n", current[0] ? "/" : "", current);
        else return COMMAND_EXIT;
        return COMMAND_OK;
    }
    int recursive = 0;
    const char *text = NULL;
    if (!strcmp(command, "write")) {
        cursor += strspn(cursor, " \t");
        if (!argument || !*cursor) goto usage;
        text = cursor;
    } else {
        if (!strcmp(command, "rm") && argument && !strcmp(argument, "-r")) {
            recursive = 1;
            argument = next_word(&cursor);
        }
        if (next_word(&cursor)) goto usage;
    }
    int listing = !strcmp(command, "ls"), changing = !strcmp(command, "cd");
    if (!listing && !changing && strcmp(command, "cat") && strcmp(command, "touch") &&
        strcmp(command, "write") && strcmp(command, "mkdir") && strcmp(command, "rm") &&
        strcmp(command, "rmdir")) {
        fputs("Comando no permitido. Ejecuta help.\n", stderr);
        return COMMAND_ERROR;
    }
    if (!argument) {
        if (listing) argument = ".";
        else if (changing) argument = SHARED_PATH;
        else goto usage;
    }
    char relative[PATH_MAX_BYTES];
    if (resolve_path(argument, relative) < 0) goto failed;
    if (listing) {
        if (list_directory(relative) < 0) goto failed;
        return COMMAND_OK;
    }
    if (changing) {
        int fd = open_directory(relative);
        if (fd < 0) goto failed;
        close(fd);
        memcpy(current, relative, strlen(relative) + 1);
        return COMMAND_OK;
    }
    if ((!strcmp(command, "rmdir") || recursive) && relative[0]) {
        size_t length = strlen(relative);
        if (!strncmp(current, relative, length) &&
            (current[length] == '\0' || current[length] == '/')) {
            errno = EBUSY;
            goto failed;
        }
    }
    char name[NAME_MAX_BYTES + 1];
    int parent = open_parent(relative, name);
    if (parent < 0) goto failed;
    int status;
    if (!strcmp(command, "cat")) status = cat_file(parent, name);
    else if (!strcmp(command, "touch") || !strcmp(command, "write"))
        status = create_file(parent, name, text);
    else if (!strcmp(command, "mkdir")) status = mkdirat(parent, name, 0770);
    else if (!strcmp(command, "rmdir")) status = unlinkat(parent, name, AT_REMOVEDIR);
    else if (recursive) status = remove_tree(parent, name, 0);
    else status = unlinkat(parent, name, 0);
    int saved = errno;
    close(parent);
    errno = saved;
    if (status < 0) goto failed;
    return COMMAND_OK;
usage:
    fputs("Argumentos no permitidos. Ejecuta help.\n", stderr);
    return COMMAND_ERROR;
failed:
    fprintf(stderr, "%s: %s\n", command, strerror(errno));
    return COMMAND_ERROR;
}

int main(int argc, char **argv)
{
    umask(0007);
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
        enum result result = run_line(line);
        if (shared_fd >= 0) close(shared_fd);
        return result == COMMAND_ERROR ? EXIT_FAILURE : EXIT_SUCCESS;
    }
    puts("GutsNet SSH Jail - consola de archivos compartidos");
    show_help();
    char line[LINE_MAX_BYTES];
    for (;;) {
        printf("gutsnet-jail:" SHARED_PATH "%s%s> ", current[0] ? "/" : "", current);
        fflush(stdout);
        if (fgets(line, sizeof(line), stdin) == NULL) break;
        if (strchr(line, '\n') == NULL && !feof(stdin)) {
            int ch;
            while ((ch = getchar()) != '\n' && ch != EOF) {}
            fputs("Comando demasiado largo.\n", stderr);
            continue;
        }
        if (run_line(line) == COMMAND_EXIT) break;
    }
    if (shared_fd >= 0) close(shared_fd);
    return EXIT_SUCCESS;
}
