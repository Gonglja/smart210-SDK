KERNELDIR := ../../linux-3.10.79

CURRDIR := $(shell pwd)


obj-m := chrdevbase.o


build: kernel_modules

kernel_modules:
	$(MAKE) -C $(KERNELDIR) M=$(CURRDIR) modules
	sudo cp *.ko ../../rootfs/lib/modules/3.10.79

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURRDIR) clean
	rm -rf *APP

