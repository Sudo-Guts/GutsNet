# GutsNet - programa estatico para un chroot sin ejecutables del sistema.
CC       ?= cc
CFLAGS   ?= -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror
TARGET   := out/gutsnet-shell
SOURCE   := src/gutsnet_shell.c

.PHONY: all clean test
all: $(TARGET)

out:
	mkdir -p out

$(TARGET): $(SOURCE) | out
	$(CC) $(CFLAGS) -static $< -o $@

test: $(TARGET)
	./$(TARGET) -c help
	./$(TARGET) -c pwd
	@output="$$(./$(TARGET) -c 'cd /' 2>&1)"; \
		echo "$$output" | grep -q "Comando no permitido"
	@if readelf -l "$(TARGET)" | grep -q 'INTERP'; then \
		echo "ERROR: el ejecutable requiere un interprete dinamico"; exit 1; \
	fi
	@echo "OK: shell estatica y lista blanca basica"

clean:
	rm -rf out
