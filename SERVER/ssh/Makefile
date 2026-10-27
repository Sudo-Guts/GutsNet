# GutsNet - programa estatico para un chroot sin ejecutables del sistema.
CC       ?= cc
CFLAGS   ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
TARGET   := out/gutsnet-shell
SOURCE   := src/gutsnet_shell.c

.PHONY: all clean test test-jail
all: $(TARGET)

out:
	mkdir -p out

$(TARGET): $(SOURCE) | out
	$(CC) $(CFLAGS) -static $< -o $@

out/test-parser: tests/test_parser.c $(SOURCE) | out
	$(CC) $(CFLAGS) $< -o $@

test: $(TARGET) out/test-parser
	./out/test-parser
	./$(TARGET) -c help
	./$(TARGET) -c pwd
	@if ./$(TARGET) -c 'cd /'; then \
		echo "ERROR: se permitio salir de /compartido"; exit 1; \
	fi
	@if ./$(TARGET) -c 'sh'; then \
		echo "ERROR: se acepto un programa externo"; exit 1; \
	fi
	@if readelf -l "$(TARGET)" | grep -q 'INTERP'; then \
		echo "ERROR: el ejecutable requiere un interprete dinamico"; exit 1; \
	fi
	@echo "OK: shell estatica y lista blanca basica"

test-jail: $(TARGET)
	python3 tests/test_shell.py

clean:
	rm -rf out
