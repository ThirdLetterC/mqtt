UNAME = $(shell uname -o)

CC = gcc
DEBUG ?= 0
SANITIZERS ?= -fsanitize=address -fsanitize=undefined -fsanitize=leak
CFLAGS = -std=c2x -Wall -Wextra -Wpedantic -Werror -D_POSIX_C_SOURCE=200809L -Iinclude
ifeq ($(DEBUG),1)
CFLAGS += -g $(SANITIZERS)
LDFLAGS += $(SANITIZERS)
endif

ifeq ($(UNAME), Msys)
MSFLAGS = -lws2_32
endif

MQTT_C_SOURCES = src/mqtt.c src/mqtt_pal.c
MQTT_C_EXAMPLES = bin/simple_publisher bin/simple_subscriber bin/reconnect_subscriber bin/bio_publisher bin/openssl_publisher
MQTT_C_UNITTESTS = bin/tests
BINDIR = bin

all: $(BINDIR) $(MQTT_C_UNITTESTS) $(MQTT_C_EXAMPLES)

bin/simple_%: examples/simple_%.c $(MQTT_C_SOURCES)
	$(CC) $(CFLAGS) $^ -lpthread $(MSFLAGS) $(LDFLAGS) -o $@

bin/reconnect_%: examples/reconnect_%.c $(MQTT_C_SOURCES)
	$(CC) $(CFLAGS) $^ -lpthread $(MSFLAGS) $(LDFLAGS) -o $@

bin/bio_%: examples/bio_%.c $(MQTT_C_SOURCES)
	$(CC) $(CFLAGS) `pkg-config --cflags openssl` -D MQTT_USE_BIO $^ -lpthread $(MSFLAGS) `pkg-config --libs openssl` $(LDFLAGS) -o $@

bin/openssl_%: examples/openssl_%.c $(MQTT_C_SOURCES)
	$(CC) $(CFLAGS) `pkg-config --cflags openssl` -D MQTT_USE_BIO $^ -lpthread $(MSFLAGS) `pkg-config --libs openssl` $(LDFLAGS) -o $@

$(BINDIR):
	mkdir -p $(BINDIR)

$(MQTT_C_UNITTESTS): tests.c $(MQTT_C_SOURCES)
	$(CC) $(CFLAGS) $^ -lcmocka $(MSFLAGS) $(LDFLAGS) -o $@

clean:
	rm -rf $(BINDIR)

check: all
	./$(MQTT_C_UNITTESTS)

format:
	clang-format -i --style=file src/*.c include/mqtt/*.h examples/*.c tests.c
