# vault.deadlight Makefile
# Minimal, portable, aims for tiny static binary

NAME       = deadlight_vault
CC         ?= gcc
CFLAGS     ?= -Wall -Wextra -O2 -std=c11 -pthread
LDFLAGS    ?=
LDLIBS     ?=

# Debug vs Release
ifeq ($(DEBUG),1)
    CFLAGS += -g -Og -DDEBUG
else
    CFLAGS += -DNDEBUG -s
endif

# === Source files =============================================================

# Your sources
SRCS = src/main.c \
       src/vault.c \
       src/cli.c \
       src/crypto_vault.c

# SQLite amalgamation (drop sqlite3.c + sqlite3.h in vendor/sqlite/)
SQLITE_DIR = vendor/sqlite
SRCS      += $(SQLITE_DIR)/sqlite3.c

# lib.deadlight crypto pieces you need (copy or symlink them here)
DEADLIGHT_DIR = lib/c/auth
SRCS          += $(DEADLIGHT_DIR)/crypto.c   # assuming this contains chacha20, pbkdf2, etc.

# === Objects & binary ========================================================

OBJS = $(SRCS:.c=.o)
TARGET = $(NAME)

# === Includes ================================================================

INCLUDES = -Iinclude \
           -I$(SQLITE_DIR) \
           -I$(DEADLIGHT_DIR)

# === Rules ===================================================================

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS) $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# === Phony targets ===========================================================

clean:
	rm -f $(OBJS) $(TARGET) *.o src/*.o vendor/sqlite/*.o lib/c/auth/*.o

test: $(TARGET)
	@echo "TODO: add simple smoke tests here"
	./$(TARGET) --help || true

# === Cross-compile examples (ARM64/aarch64) ==================================

cross-arm64:
	$(MAKE) CC=aarch64-linux-gnu-gcc \
	        CFLAGS="$(CFLAGS) -march=armv8-a" \
	        LDFLAGS="$(LDFLAGS) -static"

# === Very strict static build (good for embedded/audit) ======================

static: CFLAGS += -static -static-libgcc
static: LDFLAGS += -static
static: all

# ============================================================================

.PHONY: all clean test cross-arm64 static
