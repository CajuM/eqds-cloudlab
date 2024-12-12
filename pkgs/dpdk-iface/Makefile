.PHONY: all kmod

obj-m = dpdk_iface.o

all: kmod

kmod:
	make -C $(KDIR) M=$(PWD) EXTRA_CFLAGS= modules

clean:
	make -C $(KDIR) M=$(PWD) clean
	rm -rf *~ *.o *.ko build *.map _*install _postbuild
