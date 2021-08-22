KERNELDIR :=  ../../linux-3.10.79
CURRDIR := $(shell pwd)

obj-m := led.o

build: kernel_modules

kernel_modules:
	make -C $(KERNELDIR) M=$(CURRDIR) modules
	/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-gcc -o ledAPP ledAPP.c 

	sudo cp *.ko ../../rootfs/lib/modules/3.10.79
	sudo cp *APP ../../rootfs/lib/modules/3.10.79

clean:
	make -C $(KERNELDIR) M=$(CURRDIR) clean
	rm -rf *APP
