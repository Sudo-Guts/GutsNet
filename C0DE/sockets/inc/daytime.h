/* GutsNet - formato comun de fecha/hora para Daytime RFC 867. */
#ifndef GUTSNET_DAYTIME_H
#define GUTSNET_DAYTIME_H
#include <stddef.h>
/* Devuelve los bytes escritos (sin NUL) o 0 en caso de error. */
size_t daytime_format(char *buffer, size_t capacity);
#endif
