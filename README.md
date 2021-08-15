# smart210-SDK
smart210-SDK



## u-boot

### 编译：

```bash
make smart210_config
make all
```

### 烧录到SD卡：

```shell
#!/bin/bash
DST=/dev/mmcblk0
sudo dd iflag=sync oflag=sync if=spl/smart210-spl.bin of=$DST seek=1
sudo dd iflag=sync oflag=sync if=u-boot.bin of=$DST  seek=32
sync
echo "done."
```

### 烧录到NAND

```bash
nand erase.part bootloader
tftp 20000000 smart210-spl.bin
nand write 20000000 0 $filesize
tftp 20000000 u-boot.bin
nand write 20000000 4000 $filesize
```



### 修改分区：

vim include/configs/smart210.h

```c
#define MTDPARTS_DEFAULT        "mtdparts=s5p-nand:256k(bootloader)"\
                                ",128k(device_tree)"\
                                ",128k(params)"\
                                ",5m(kernel)"\
                                ",-(rootfs)"

#define CONFIG_ENV_SIZE                 (128 << 10)     /* 128KiB, 0x20000 */
#define CONFIG_ENV_ADDR                 (384 << 10)     /* 384KiB(u-boot + device_tree), 0x60000 */
#define CONFIG_ENV_OFFSET               (384 << 10)     /* 384KiB(u-boot + device_tree), 0x60000 */
```

修改启动参数：

```
#define CONFIG_BOOTCOMMAND	"nand read.jffs2 0x30007FC0 0x80000 0x500000;  bootm 0x30007FC0 "
```

set bootargs noinitrd root=/dev/mtdblock4 rw init=/linuxrc console=ttySAC0,115200

## kernel

### 编译：

```bash
make s5pv210_defconfig
make uImage
```

### 烧录

```bash
nand erase.part kernel
tftp 20000000 uImage
nand write.yaffs  20000000 80000 $filesize
nand write  20000000 80000 $filesize
or
nand erase.part kernel;tftp 20000000 uImage;nand write  20000000 80000 $filesize
```



### 修改分区

对应与bootloader

vim arch/arm/mach-s5pv210/mach-smdkv210.c

```c
/* nand info (add by Flinn) */
static struct mtd_partition smdk_default_nand_part[] = {
        [0] = {
                .name   = "bootloader",
                .size   = SZ_256K,
                .offset = 0,
        },
        [1] = {
                .name   = "device_tree",
                .offset = MTDPART_OFS_APPEND,
                .size   = SZ_128K,
        },
        [2] = {
                .name   = "params",
                .offset = MTDPART_OFS_APPEND,
                .size   = SZ_128K,
        },
        [3] = {
                .name   = "kernel",
                .offset = MTDPART_OFS_APPEND,
                .size   = SZ_1M + SZ_4M,
        },

        [4] = {
                .name   = "rootfs",
                .offset = MTDPART_OFS_APPEND,
                .size   = MTDPART_SIZ_FULL,
        }
};
```







## busybox

首先打开make menuconfig配置交叉编译工具链的路径为



```bash
# 1配置相关选项
make menuconfig
# 1.1设置交叉编译工具链
# Busybox Settings  --->   
#       Build Options  ---> 
#               (/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-) Cross Compiler prefix  
/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-

# 1.2设置make install后的路径
# Busybox Settings  --->   
#       Installation Options ("make install" behavior)  ---> 
#               (./_install) BusyBox installation prefix  

# 2编译安装
# 生成的数据位置在1.2配置的路径下
make -j4 && make install

# 3将产物拷贝至 rootfs文件夹下，替换原来的

# 4生成jfss2镜像
# 此处参数意义：
#    rootfs/   要打包的文件系统
#    -s        页大小
#    -e        为要指定的擦除块的大小，板子芯片的nand块大小为128k(128*1024=0x20000)，此处两个值可通过在uboot中使用命令nand info查看
#    --pad     为生成镜像的大小 不足xx时以脏数据填充，大于时以实际数据大小为主
sudo mkfs.jffs2  -r rootfs/ -o rootfs.jffs2 -s 0x800 -e 0x20000 --pad=0x800000 -n
```



## rootfs

注意：

busybox不要采用高版本，使用busybox-1.7.0为宜。

### 烧录

```bash
tftp 20000000 rootfs.yaffs2
nand erase.part rootfs
nand write.yaffs 20000000 0x580000 $filesize
```

jffs2

```bash
tftp 20000000 rootfs.jffs2
nand erase.part rootfs
nand write.jffs2 20000000 580000 $filesize
set bootargs console=ttySAC0,115200 root=/dev/mtdblock4 rootfstype=jffs2
```

如何制作jffs2镜像

```bash
#此处参数意义：rootfs/要打包的文件系统、-s页大小、-e为要指定的擦除块的大小，板子芯片的nand块大小为128k(128*1024=0x20000)，此处两个值可通过在uboot中使用命令nand info查看
sudo mkfs.jffs2  -r rootfs/ -o rootfs.jffs2 -s 0x800 -e 0x20000 --pad=0x800000 -n
```

jffs2可能会出现的错误

> Q：在启动过程中出现at91sam user.warn kernel: Empty flash at 0x00f0fffc ends at 0x00f10000问题
>
> A：在mkfs.jffs2的时候，加上-e 0x20000指定擦除块的大小。-e是指定擦除块的大小，我们使用的nandflash的块大小为128K字节，因此-e后的参数为(128*1024)10=(20000)16。
>
>  
>
> Q：启动的时候出现CLEANMARKER node found at 0x00f10000 has totlen 0xc != normal 0x0问题。
>
> A：在mkfs.jffs2的时候，加上-n选项。-n, --no-cleanmarkers。指明不添加清楚标记（nand flash 有自己的校检块，存放相关的信息。）如果挂载后会出现类似：CLEANMARKER node found at 0x0042c000 has totlen 0xc != normal 0x0 的警告，则加上-n 就会消失。
>
>  
>
> Q：解决jffs2_scan_eraseblock(): Magic bitmask 0x1985 not found at 0x01649298: 0xa25e instead问题的方法
>
> A：在mkfs.jffs2的时候加上-s 2048（页大小，由芯片决定）以及-l(小端模式)两个选项。-s是指明页的大小，我们使用的nandflash的页的大小为2048字节。-l指明为小端模式，一般嵌入式下均为小端模式。
>
>  
>
> 说明：
>
> 1、  在文件系统制作的过程，均需要使用root用户权限；
>
> 2、  一般嵌入式下只有root用户登录，因此文件系统中的所有文件都需要具有root可执行权限，如果用其他用户登录，请保证文件系统中文件（特别是自己添加的文件）的相应可执行权限。





### nfs

```bash
set bootargs noinitrd root=/dev/nfs nfsroot=192.168.1.104:/home/flinn/work/rootfs/fs_mini_mdev  ip=192.168.1.123:192.168.1.104:192.168.1.1:255.255.255.0::eth0:off init=/linuxrc console=ttySAC0，115200
```

