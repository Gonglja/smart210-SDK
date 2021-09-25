#!/bin/bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-

#make s5pv210_fin_defconfig 
make LOADADDR=0x20008000 uImage -j4
make dtbs

echo "copy to ../rootfs/"
cp arch/arm/boot/uImage ../rootfs/
cp arch/arm/boot/dts/s5pv210-smart210.dtb ../rootfs/
