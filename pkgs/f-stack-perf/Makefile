APP = f-stack-perf

CC ?= gcc
AR ?= gcc-ar
PKGCONF ?= pkg-config
F_STACK ?=

SRCS_ARP =
SRCS_ARP += rtmsg.c
SRCS_ARP += arp.c

OBJS_ARP = $(SRCS_ARP:.c=.o)

CFLAGS_ARP += $(shell $(PKGCONF) --cflags libdpdk)

SRCS = main.c

OBJS = $(SRCS:.c=.o)

CFLAGS ?=
CFLAGS += -I.
CFLAGS += -Wall
CFLAGS += -Wno-address-of-packed-member

CFLAGS += -I$(F_STACK)/include
CFLAGS += $(shell $(PKGCONF) --cflags libdpdk)
CFLAGS += $(shell $(PKGCONF) --cflags libcrypto)

CFLAGS_ARP += -Wall
CFLAGS_ARP += -D__BSD_VISIBLE
CFLAGS_ARP += -I$(F_STACK)/include/ffcompat

LDFLAGS ?=
LDFLAGS += -fwhole-program
LDFLAGS += -L$(F_STACK)/lib -Wl,--whole-archive -lfstack -Wl,--no-whole-archive -lffcompat
LDFLAGS += $(subst -l:librte_bpf.a,,$(shell $(PKGCONF) --libs libdpdk)) -lrte_net_bond
LDFLAGS += $(shell $(PKGCONF) --libs libcrypto)

all: $(APP)

$(OBJS): $(@:.o=.c)
	$(CC) -c $(CFLAGS) $(@:.o=:.c) -o $@

$(OBJS_ARP): $(@:.o=.c)
	$(CC) -c $(CFLAGS_ARP) $(@:.o=.c) -o $@

arp.a: $(OBJS_ARP)
	$(AR) -cqs $@ $(OBJS_ARP)

$(APP): $(SRCS) arp.a Makefile
	$(CC) $(CFLAGS) $(SRCS) -o $@ arp.a $(LDFLAGS)

clean:
	rm -f $(APP)
