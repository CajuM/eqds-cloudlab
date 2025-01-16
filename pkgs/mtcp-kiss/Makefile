APP = mtcp-kiss

CC ?= gcc
PKGCONF ?= pkg-config

SRCS-y = main.c

CFLAGS ?= 
LDFLAGS ?=

include $(RTE_SDK)/mk/rte.vars.mk

CFLAGS += -Wall -Werror

LDFLAGS += -L$(MTCP)/lib --whole-archive -lmtcp --no-whole-archive
LDFLAGS += -L$(GMP)/lib -lgmp

include $(RTE_SDK)/mk/rte.extapp.mk
