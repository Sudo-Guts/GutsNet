/* GutsNet - Daytime RFC 867: formato ASCII UTC terminado en CRLF. */
#define _POSIX_C_SOURCE 200809L
#include "daytime.h"
#include <stdio.h>
#include <time.h>

size_t daytime_format(char *buffer, size_t capacity)
{
    time_t now = time(NULL);
    struct tm utc;
    if (now == (time_t)-1 || gmtime_r(&now, &utc) == NULL) {
        return 0;
    }
    int result = snprintf(buffer, capacity,
                          "%04d-%02d-%02d %02d:%02d:%02d UTC\r\n",
                          utc.tm_year + 1900, utc.tm_mon + 1, utc.tm_mday,
                          utc.tm_hour, utc.tm_min, utc.tm_sec);
    if (result < 0 || (size_t)result >= capacity) {
        return 0;
    }
    return (size_t)result;
}
