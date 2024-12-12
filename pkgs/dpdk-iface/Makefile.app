APP = dpdk_iface_main

SRCS-y = dpdk_iface_main.c

CFLAGS ?=
LDFLAGS ?=

include $(RTE_SDK)/mk/rte.vars.mk
include $(RTE_SDK)/mk/rte.extapp.mk
