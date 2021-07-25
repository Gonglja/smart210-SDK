/*
 * Copyright (c) 2004-2008 Texas Instruments
 *
 * (C) Copyright 2002
 * Gary Jennejohn, DENX Software Engineering, <garyj@denx.de>
 *
 * SPDX-License-Identifier:	GPL-2.0+
 */
/* 指定输出可执行文件：elf32位小端格式*/
OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
/* 指定输出可执行文件的目标架构：arm*/
OUTPUT_ARCH(arm)
/* 指定输出可执行文件的入口地址（其实代码段）：_start*/
ENTRY(_start)
SECTIONS
{
	/*
	 * 设置0的原因是，arm内核的处理器，三点后？默认是从0x00000000处启动
	 * 1.以STM32为例：片内的nor-flash的起始地址是0x08000000,这里是我们烧写u-boot的位置
	 * 2.上电后，系统会自动将该地址（0x0800:0000）映射到0x0000:0000（硬件完成）
	 */
	. = 0x00000000;
	
	/*
	 * 代码以4字节对齐，.text为代码段
	 * 各个段按先后顺序依次排列
	 * 在cortex-m的内核中，首地址存放的是主堆栈的地址，其次存放中断相互向量表
	 */
	. = ALIGN(4);
	.text :
	{
		*(.__image_copy_start)	/*u-boot里默认会将u-boot的镜像拷贝到ram(sdram、ddr...)*/
		CPUDIR/start.o (.text*)	/*存放CPUDIR/start.o中的所有.text段*/
		*(.text*)		/*存放其他*.o中的所有.text段*/
	}

	/*
	 * .rodata段，以4字节对齐处开始
	 */
	. = ALIGN(4);
	.rodata : { *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.rodata*))) }

	/*
	 * .data段，以4字节对齐处开始
	 */
	. = ALIGN(4);
	.data : {
		*(.data*)
	}

	. = ALIGN(4);

	. = .;

	/* 
	 * u_boot_list段,确保是以4字节对齐处开始 
	 * 这里存放的都是u_boot_list中的函数
	 * 例如:base/bdinfo/blkcache/cmp....
	 * 具体的可参看./u-boot.map .u_boot_list
	 * tips:要想优化编译出来的u-boot.bin大小,可以参看此文件进行对照裁剪
	 */
	. = ALIGN(4);
	.u_boot_list : {
		KEEP(*(SORT(.u_boot_list*)));
	}

	/* 
	 * __image_copy_end段,确保是以4字节对齐处开始 
	 * 镜像拷贝的完成
	 */
	. = ALIGN(4);

	.image_copy_end :
	{
		*(.__image_copy_end)
	}

	.rel_dyn_start :
	{
		*(.__rel_dyn_start)
	}

	.rel.dyn : {
		*(.rel*)
	}

	.rel_dyn_end :
	{
		*(.__rel_dyn_end)
	}

	.end :
	{
		*(.__end)
	}

        /* bin文件结束 */
	_image_binary_end = .;

	/*
	 * Deprecated: this MMU section is used by pxa at present but
	 * should not be used by new boards/CPUs.
	 */
	. = ALIGN(4096);
	.mmutable : {
		*(.mmutable)
	}

/*
 * Compiler-generated __bss_start and __bss_end, see arch/arm/lib/bss.c
 * __bss_base and __bss_limit are for linker only (overlay ordering)
 */

	.bss_start __rel_dyn_start (OVERLAY) : {
		KEEP(*(.__bss_start));
		__bss_base = .;
	}

	.bss __bss_base (OVERLAY) : {
		*(.bss*)
		 . = ALIGN(4);
		 __bss_limit = .;
	}

	.bss_end __bss_limit (OVERLAY) : {
		KEEP(*(.__bss_end));
	}

	.dynsym _image_binary_end : { *(.dynsym) }
	.dynbss : { *(.dynbss) }
	.dynstr : { *(.dynstr*) }
	.dynamic : { *(.dynamic*) }
	.plt : { *(.plt*) }
	.interp : { *(.interp*) }
	.gnu.hash : { *(.gnu.hash) }
	.gnu : { *(.gnu*) }
	.ARM.exidx : { *(.ARM.exidx*) }
	.gnu.linkonce.armexidx : { *(.gnu.linkonce.armexidx.*) }
}
