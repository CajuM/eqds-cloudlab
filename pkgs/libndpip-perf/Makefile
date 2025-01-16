APP = eqds-tcp-perf

CC ?= gcc
PKGCONF ?= pkg-config

SRCS-y = main.c

CFLAGS ?=
CFLAGS += -Wall -Werror
CFLAGS += -Wno-address-of-packed-member

CFLAGS += $(shell $(PKGCONF) --cflags ndpip)
LDFLAGS += $(shell $(PKGCONF) --static --libs ndpip)

.PHONY: all

all: $(APP)

$(APP): $(SRCS-y) Makefile
	$(CC) $(CFLAGS) $(SRCS-y) -o $@ $(LDFLAGS)

clean:
	rm -f $(APP)
