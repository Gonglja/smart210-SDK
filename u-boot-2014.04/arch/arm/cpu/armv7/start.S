/*
 * armboot - Startup Code for OMAP3530/ARM Cortex CPU-core
 *
 * Copyright (c) 2004	Texas Instruments <r-woodruff2@ti.com>
 *
 * Copyright (c) 2001	Marius Gröger <mag@sysgo.de>
 * Copyright (c) 2002	Alex Züpke <azu@sysgo.de>
 * Copyright (c) 2002	Gary Jennejohn <garyj@denx.de>
 * Copyright (c) 2003	Richard Woodruff <r-woodruff2@ti.com>
 * Copyright (c) 2003	Kshitij <kshitij@ti.com>
 * Copyright (c) 2006-2008 Syed Mohammed Khasim <x0khasim@ti.com>
 *
 * SPDX-License-Identifier:	GPL-2.0+
 */

#include <asm-offsets.h>
#include <config.h>
#include <version.h>
#include <asm/system.h>
#include <linux/linkage.h>

/*
 * 整个分为几部分
 * 1.初始化异常向量表
 * 2.设置CPU SVC模式，关中断
 * 3.配置CP15 设置异常向量入口
 * 4.跳转至PC15初始化配置
 * 5.跳转至cpu_init_crit
 * 6.跳转到_main
 */
 
/*
 * b指令：简单的程序跳转，跳转到目标标号处执行 
 * bl指令：带链接程序跳转，在跳转之前，将当前PC保存到R14中，也就有返回地址到R14中，在子程序返回时只需要MOV PC，LR即可
 * .global声明_start为全局符号，_start就会被链接器链接到，也就是链接脚本中的入口地址了。之后是一系列ARM的异常向量表。8种异常分别占用4个字节，因此每种异常入口处都填写一条跳转指令，直接跳转到相应的异常处理函数中，reset异常是直接跳转到reset函数，其他7种异常是用ldr将处理函数入口地址加载到pc中
 */
.globl _start   				/* .globl指示告诉汇编器，_start是一个全局符号*/
_start: b	reset				/* 跳转到reset符号处*/
	ldr	pc, _undefined_instruction	/* 未定义指令异常*/
	ldr	pc, _software_interrupt		/* 软中断，Linux系统调用*/
	ldr	pc, _prefetch_abort		/* 预取址中止，取不到下一条指令*/
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq			/* 中断*/
	ldr	pc, _fiq			/* 快中断*/
	
/*
 * 如果CONFIG_SPL_BUILD定义了，即处于BL1的阶段，
 * 此时发生_undefined_instruction（未定义指令异常），那么就将_undefined_instruction赋给pc，也就是跳转到_undefined_instruction本身，即死循环；
 * 如果CONFIG_SPL_BUILD没有定义，即处于BL2的阶段，
 * 此时发生_undefined_instruction（未定义指令异常），那么就将undefined_instruction赋给pc，也就是跳转到undefined_instruction的部分。
 */
#ifdef CONFIG_SPL_BUILD
_undefined_instruction: .word _undefined_instruction
_software_interrupt:	.word _software_interrupt
_prefetch_abort:	.word _prefetch_abort
_data_abort:		.word _data_abort
_not_used:		.word _not_used
_irq:			.word _irq
_fiq:			.word _fiq
_pad:			.word 0x12345678 /* now 16*4=64 */
#else
.globl _undefined_instruction
_undefined_instruction: .word undefined_instruction
.globl _software_interrupt
_software_interrupt:	.word software_interrupt
.globl _prefetch_abort
_prefetch_abort:	.word prefetch_abort
.globl _data_abort
_data_abort:		.word data_abort
.globl _not_used
_not_used:		.word not_used
.globl _irq
_irq:			.word irq
.globl _fiq
_fiq:			.word fiq
_pad:			.word 0x12345678 /* now 16*4=64 */
#endif	/* CONFIG_SPL_BUILD */

.global _end_vect       /*异常向量和处理部分结束*/
_end_vect:

	.balignl 16,0xdeadbeef /*下一句需要16字节对齐，若没有满，就将0xdeadbeef填入，直至对其*/
/*************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************/

#ifdef CONFIG_USE_IRQ        //如果使用中断IRQ（肯定用到的）
/* IRQ stack memory (calculated at run-time) */
.globl IRQ_STACK_START       //表示堆栈指针开始的地方
IRQ_STACK_START:
	.word	0x0badc0de   //此时不知道堆栈在哪里，就放入没有意义的非法地址，运行时该值会被修改

/* IRQ stack memory (calculated at run-time) */
.globl FIQ_STACK_START
FIQ_STACK_START:
	.word 0x0badc0de
#endif

/* IRQ stack memory (calculated at run-time) + 8 bytes */
.globl IRQ_STACK_START_IN
IRQ_STACK_START_IN:
	.word	0x0badc0de

/*
 * the actual reset code
 */

reset:
	bl	save_boot_params       //跳转到save_boot_params符号处
	/*
	 * disable interrupts (FIQ and IRQ), also set the cpu to SVC32 mode,
	 * except if in HYP mode already
	 */
	mrs	r0, cpsr					//将cpsr寄存器的值读到r0中
	and	r1, r0, #0x1f		@ mask mode bits
	teq	r1, #0x1a		@ test for HYP mode
	bicne	r0, r0, #0x1f		@ clear all mode bits  
	orrne	r0, r0, #0x13		@ set SVC mode 		//更改处理器模式为SVC模式
	orr	r0, r0, #0xc0		@ disable FIQ and IRQ	//将I、F位（7、6位）置1 也即0xc0，关闭快中断和中断
	msr	cpsr,r0						//将r0的内容写入cpsr寄存器

/*
 * Setup vector:
 * (OMAP4 spl TEXT_BASE is not 32 byte aligned.
 * Continue to use ROM code vector only in OMAP4 spl)
 */
 
 /*
  * 这部分代码通过对协处理器CP15进行操作，设置了处理器的异常向量入口地址为_start。
  * 这是因为ARM默认的异常向量表入口在0x0地址，然而S5PV210中0x0地址存放的是IROM，不可修改，自然不可能存放异常向量表，所以需要修改异常向量表入口，将它们映射到其他位置上去。
  */
#if !(defined(CONFIG_OMAP44XX) && defined(CONFIG_SPL_BUILD))
	/* Set V=0 in CP15 SCTRL register - for VBAR to point to vector */
	mrc	p15, 0, r0, c1, c0, 0	@ Read CP15 SCTRL Register
	bic	r0, #CR_V		@ V = 0
	mcr	p15, 0, r0, c1, c0, 0	@ Write CP15 SCTRL Register

	/* Set vector address in CP15 VBAR register */
	ldr	r0, =_start
	mcr	p15, 0, r0, c12, c0, 0	@Set VBAR
#endif

	/* the mask ROM code should have PLL and others stable */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_cp15
	bl	cpu_init_crit
#endif

	bl	_main

/*------------------------------------------------------------------------------*/

ENTRY(c_runtime_cpu_setup)
/*
 * If I-cache is enabled invalidate it
 */
#ifndef CONFIG_SYS_ICACHE_OFF
	mcr	p15, 0, r0, c7, c5, 0	@ invalidate icache
	mcr     p15, 0, r0, c7, c10, 4	@ DSB
	mcr     p15, 0, r0, c7, c5, 4	@ ISB
#endif
/*
 * Move vector table
 */
	/* Set vector address in CP15 VBAR register */
	ldr     r0, =_start
	mcr     p15, 0, r0, c12, c0, 0  @Set VBAR

	bx	lr

ENDPROC(c_runtime_cpu_setup)

/*************************************************************************
 *
 * void save_boot_params(u32 r0, u32 r1, u32 r2, u32 r3)
 *	__attribute__((weak));
 *
 * Stack pointer is not yet initialized at this moment
 * Don't save anything to stack even if compiled with -O0
 *
 *************************************************************************/
ENTRY(save_boot_params)
	bx	lr			@ back to my caller
ENDPROC(save_boot_params)
	.weak	save_boot_params

/*************************************************************************
 *
 * cpu_init_cp15
 *
 * Setup CP15 registers (cache, MMU, TLBs). The I-cache is turned on unless
 * 配置CP15，关闭的cache、MMU、TLBs。icache视情况
 * CONFIG_SYS_ICACHE_OFF is defined.
 *
 *************************************************************************/
ENTRY(cpu_init_cp15)
	/*
	 * Invalidate L1 I/D
	 */
	mov	r0, #0			@ set up for MCR
	mcr	p15, 0, r0, c8, c7, 0	@ invalidate TLBs 	//失效TLBs
	mcr	p15, 0, r0, c7, c5, 0	@ invalidate icache	//失效icache
	mcr	p15, 0, r0, c7, c5, 6	@ invalidate BP array	//失效分支预测
	mcr     p15, 0, r0, c7, c10, 4	@ DSB			//数据同步屏障
	mcr     p15, 0, r0, c7, c5, 4	@ ISB			//指令同步屏障

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0				//将SCTLR的值赋给r0
	bic	r0, r0, #0x00002000	@ clear bits 13 (--V-)	//清零第13位，异常向量映射到0x00000000
	bic	r0, r0, #0x00000007	@ clear bits 2:0 (-CAM)	//失效dcache，失效对齐检查，禁用MMU
	orr	r0, r0, #0x00000002	@ set bit 1 (--A-) Align//使能对齐检查模式
	orr	r0, r0, #0x00000800	@ set bit 11 (Z---) BTB	//使能分支预测
#ifdef CONFIG_SYS_ICACHE_OFF
	bic	r0, r0, #0x00001000	@ clear bit 12 (I) I-cache
#else
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-cache //使能icache
#endif
	mcr	p15, 0, r0, c1, c0, 0				 //将r0的值赋给SCTLR

#ifdef CONFIG_ARM_ERRATA_716044
	mrc	p15, 0, r0, c1, c0, 0	@ read system control register
	orr	r0, r0, #1 << 11	@ set bit #11
	mcr	p15, 0, r0, c1, c0, 0	@ write system control register
#endif

#if (defined(CONFIG_ARM_ERRATA_742230) || defined(CONFIG_ARM_ERRATA_794072))
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 4		@ set bit #4
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

#ifdef CONFIG_ARM_ERRATA_743622
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 6		@ set bit #6
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

#ifdef CONFIG_ARM_ERRATA_751472
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 11	@ set bit #11
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif
#ifdef CONFIG_ARM_ERRATA_761320
	mrc	p15, 0, r0, c15, c0, 1	@ read diagnostic register
	orr	r0, r0, #1 << 21	@ set bit #21
	mcr	p15, 0, r0, c15, c0, 1	@ write diagnostic register
#endif

	mov	pc, lr			@ back to my caller //子过程运行结束，跳转回去
ENDPROC(cpu_init_cp15)

#ifndef CONFIG_SKIP_LOWLEVEL_INIT
/*************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************/
ENTRY(cpu_init_crit)
	/*
	 * Jump to board specific initialization...
	 * The Mask ROM will have already initialized
	 * basic memory. Go here to bump up clock rate and handle
	 * wake up conditions.
	 */
	b	lowlevel_init		@ go setup pll,mux,memory
ENDPROC(cpu_init_crit)
#endif

#ifndef CONFIG_SPL_BUILD
/*
 *************************************************************************
 *
 * Interrupt handling
 *
 *************************************************************************
 */
@
@ IRQ stack frame.
@
#define S_FRAME_SIZE	72

#define S_OLD_R0	68
#define S_PSR		64
#define S_PC		60
#define S_LR		56
#define S_SP		52

#define S_IP		48
#define S_FP		44
#define S_R10		40
#define S_R9		36
#define S_R8		32
#define S_R7		28
#define S_R6		24
#define S_R5		20
#define S_R4		16
#define S_R3		12
#define S_R2		8
#define S_R1		4
#define S_R0		0

#define MODE_SVC 0x13
#define I_BIT	 0x80

/*
 * use bad_save_user_regs for abort/prefetch/undef/swi ...
 * use irq_save_user_regs / irq_restore_user_regs for IRQ/FIQ handling
 */

	.macro	bad_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE		@ carve out a frame on current
						@ user stack
	stmia	sp, {r0 - r12}			@ Save user registers (now in
						@ svc mode) r0-r12
	ldr	r2, IRQ_STACK_START_IN		@ set base 2 words into abort
						@ stack
	ldmia	r2, {r2 - r3}			@ get values for "aborted" pc
						@ and cpsr (into parm regs)
	add	r0, sp, #S_FRAME_SIZE		@ grab pointer to old stack

	add	r5, sp, #S_SP
	mov	r1, lr
	stmia	r5, {r0 - r3}			@ save sp_SVC, lr_SVC, pc, cpsr
	mov	r0, sp				@ save current stack into r0
						@ (param register)
	.endm

	.macro	irq_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	add	r8, sp, #S_PC			@ !! R8 NEEDS to be saved !!
						@ a reserved stack spot would
						@ be good.
	stmdb	r8, {sp, lr}^			@ Calling SP, LR
	str	lr, [r8, #0]			@ Save calling PC
	mrs	r6, spsr
	str	r6, [r8, #4]			@ Save CPSR
	str	r0, [r8, #8]			@ Save OLD_R0
	mov	r0, sp
	.endm

	.macro	irq_restore_user_regs
	ldmia	sp, {r0 - lr}^			@ Calling r0 - lr
	mov	r0, r0
	ldr	lr, [sp, #S_PC]			@ Get PC
	add	sp, sp, #S_FRAME_SIZE
	subs	pc, lr, #4			@ return & move spsr_svc into
						@ cpsr
	.endm

	.macro get_bad_stack
	ldr	r13, IRQ_STACK_START_IN		@ setup our mode stack (enter
						@ in banked mode)

	str	lr, [r13]			@ save caller lr in position 0
						@ of saved stack
	mrs	lr, spsr			@ get the spsr
	str	lr, [r13, #4]			@ save spsr in position 1 of
						@ saved stack

	mov	r13, #MODE_SVC			@ prepare SVC-Mode
	@ msr	spsr_c, r13
	msr	spsr, r13			@ switch modes, make sure
						@ moves will execute
	mov	lr, pc				@ capture return pc
	movs	pc, lr				@ jump to next instruction &
						@ switch modes.
	.endm

	.macro get_bad_stack_swi
	sub	r13, r13, #4			@ space on current stack for
						@ scratch reg.
	str	r0, [r13]			@ save R0's value.
	ldr	r0, IRQ_STACK_START_IN		@ get data regions start
						@ spots for abort stack
	str	lr, [r0]			@ save caller lr in position 0
						@ of saved stack
	mrs	lr, spsr			@ get the spsr
	str	lr, [r0, #4]			@ save spsr in position 1 of
						@ saved stack
	ldr	lr, [r0]			@ restore lr
	ldr	r0, [r13]			@ restore r0
	add	r13, r13, #4			@ pop stack entry
	.endm

	.macro get_irq_stack			@ setup IRQ stack
	ldr	sp, IRQ_STACK_START
	.endm

	.macro get_fiq_stack			@ setup FIQ stack
	ldr	sp, FIQ_STACK_START
	.endm

/*
 * exception handlers
 */
	.align	5
undefined_instruction:
	get_bad_stack
	bad_save_user_regs
	bl	do_undefined_instruction

	.align	5
software_interrupt:
	get_bad_stack_swi
	bad_save_user_regs
	bl	do_software_interrupt

	.align	5
prefetch_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_prefetch_abort

	.align	5
data_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_data_abort

	.align	5
not_used:
	get_bad_stack
	bad_save_user_regs
	bl	do_not_used

#ifdef CONFIG_USE_IRQ

	.align	5
irq:
	get_irq_stack
	irq_save_user_regs
	bl	do_irq
	irq_restore_user_regs

	.align	5
fiq:
	get_fiq_stack
	/* someone ought to write a more effective fiq_save_user_regs */
	irq_save_user_regs
	bl	do_fiq
	irq_restore_user_regs

#else

	.align	5
irq:
	get_bad_stack
	bad_save_user_regs
	bl	do_irq

	.align	5
fiq:
	get_bad_stack
	bad_save_user_regs
	bl	do_fiq

#endif /* CONFIG_USE_IRQ */
#endif /* CONFIG_SPL_BUILD */
