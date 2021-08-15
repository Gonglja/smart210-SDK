#!/bin/bash

#make smart210_defconfig

make uImage -j4

echo "copy to ../rootfs/"
cp arch/arm/boot/uImage ../rootfs/
