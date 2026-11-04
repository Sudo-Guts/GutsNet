/*
 * =============================================================================
 *  Proyecto : GutsNet
 *  Archivo  : SERVER/ssh/tests/test_parser.c
 * -----------------------------------------------------------------------------
 *
 *  Regresiones del analizador de argumentos y nombres UTF-8 sin requerir chroot.
 *
 * =============================================================================
 */
#define main gutsnet_shell_entrypoint
#include "../src/gutsnet_shell.c"
#undef main
#include <assert.h>

static void check_words(const char *input, const char *first, const char *second) {
    char line[LINE_MAX_BYTES];
    snprintf(line, sizeof(line), "%s", input);
    char *cursor = line;
    int invalid = 0;
    assert(strcmp(next_word(&cursor, &invalid), first) == 0);
    assert(strcmp(next_word(&cursor, &invalid), second) == 0);
    assert(next_word(&cursor, &invalid) == NULL);
    assert(!invalid);
}

static void check_invalid(const char *input) {
    char line[LINE_MAX_BYTES];
    snprintf(line, sizeof(line), "%s", input);
    char *cursor = line;
    int invalid = 0;
    while (next_word(&cursor, &invalid)) {}
    assert(invalid);
}

int main(void) {
    const char *valid[] = {"video_01.mp4", "Mi canción.mp3", "Señal 🎵.mp3", "cita\"final.mp4", "$(literal).mp3"};
    const char *invalid[] = {"", ".oculto", "../fuera", "mal\\nombre", "inicio ", " inicio", "control\n", "\xc0\xaf", "\xed\xa0\x80", "\xf4\x90\x80\x80", "\xf0\x9f"};
    for (size_t i = 0; i < sizeof(valid) / sizeof(valid[0]); ++i) assert(safe_name(valid[i]));
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) assert(!safe_name(invalid[i]));
    check_words("rm \"Mi canción.mp3\"", "rm", "Mi canción.mp3");
    check_words("rm 'Mi canción.mp3'", "rm", "Mi canción.mp3");
    check_words("rm Mi\\ video.mp4", "rm", "Mi video.mp4");
    check_words("rm \"cita\\\"final.mp4\"", "rm", "cita\"final.mp4");
    check_words("rm '$(literal).mp3'", "rm", "$(literal).mp3");
    check_invalid("rm \"sin cerrar.mp4");
    check_invalid("rm uno;id");
    check_invalid("cat $(id)");
    check_invalid("touch nota > archivo");
    check_invalid("rm incompleto\\");
    const char *ssh_destinations[] = {"gutsjail@192.168.1.10", "alumno@servidor.utm.mx", "root@localhost", "user_1@::1", "user.name@2001:db8::1", "user@host."};
    const char *ssh_invalid[] = {"", "localhost", "@host", "-o@host", ".user@host", "user@", "user@-o", "user@host extra", "user@$(id)", "user@host;id", "user@@host", "user@a..b", "user@a-.b", "user@a.-b", "user@host/path", "user@ssh://host", "user@invalid:22", "user@192.168.1.1%eth0", "user@[::1]"};
    const char *ports[] = {"1", "22", "2222", "65535", "00022"};
    const char *bad_ports[] = {"", "0", "65536", "-1", "+22", "22x", "22 ", " 22", "999999999999999"};
    for (size_t i = 0; i < sizeof(ssh_destinations) / sizeof(ssh_destinations[0]); ++i) assert(valid_ssh_destination(ssh_destinations[i]));
    for (size_t i = 0; i < sizeof(ssh_invalid) / sizeof(ssh_invalid[0]); ++i) assert(!valid_ssh_destination(ssh_invalid[i]));
    for (size_t i = 0; i < sizeof(ports) / sizeof(ports[0]); ++i) assert(valid_ssh_port(ports[i]));
    for (size_t i = 0; i < sizeof(bad_ports) / sizeof(bad_ports[0]); ++i) assert(!valid_ssh_port(bad_ports[i]));
    char too_long[350];
    memset(too_long, 'a', sizeof(too_long));
    too_long[65] = '@';
    too_long[70] = '\0';
    assert(!valid_ssh_destination(too_long));
    too_long[64] = '@';
    too_long[65] = 'a';
    too_long[70] = '\0';
    assert(valid_ssh_destination(too_long));
    const char *denied_ssh[] = {"ssh", "ssh host", "ssh -p", "ssh -p 22", "ssh -p 0 user@host", "ssh -p 65536 user@host", "ssh user@host id", "ssh user@host -oProxyCommand=id", "ssh -F /compartido/config user@host", "ssh -oProxyCommand=id user@host", "ssh -L 8080:host:80 user@host", "ssh -J proxy user@host"};
    for (size_t i = 0; i < sizeof(denied_ssh) / sizeof(denied_ssh[0]); ++i) {
        char line[LINE_MAX_BYTES];
        snprintf(line, sizeof(line), "%s", denied_ssh[i]);
        assert(run_line(line) == COMMAND_ERROR);
    }
    puts("OK: nombres UTF-8, espacios y comillas; sin expansion ni operadores de shell.");
    puts("OK: destinos y puertos SSH; rechazo de comandos, proxies y opciones arbitrarias.");
    return 0;
}
