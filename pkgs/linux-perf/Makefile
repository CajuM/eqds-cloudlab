APP = linux-perf

CC ?= gcc

SRCS-y = main.c

CFLAGS ?=
CFLAGS += -Wall
CFLAGS += -Wno-address-of-packed-member

.PHONY: all

all: $(APP)

$(APP): $(SRCS-y) Makefile
	$(CC) $(CFLAGS) $(SRCS-y) -o $@ $(LDFLAGS)

clean:
	rm -f $(APP)
