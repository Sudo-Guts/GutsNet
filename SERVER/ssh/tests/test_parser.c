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
    puts("OK: nombres UTF-8, espacios y comillas; sin expansion ni operadores de shell.");
    return 0;
}
