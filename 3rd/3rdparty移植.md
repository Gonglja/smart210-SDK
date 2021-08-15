### 1 libffi移植

#### 1.1 下载源码

打开 ftp://sourceware.org/pub/libffi/ ，下载所需版本的源码，在此我选择最新版源码

#### 1.2 解压文件

```bash
tar -zxvf libffi-3.3.tar.gz
```

#### 1.3 编译文件

```bash
CROSS=/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-

mkdir build_arm && cd build_arm
../configure \
CC=${CROSS}gcc \
CXX=${CROSS}g++ \
READELF=${CROSS}readelf \
--prefix=`pwd`/_install \
--host=arm-linux  \
--enable-shared 

make && make install
```





### 2 zlib移植

#### 2.1 下载源码

打开http://www.zlib.net/，找到The current release is publicly available here

选择Pick a mirror下载tar.gz格式源码 

zlib-1.2.11.tar.gz

#### 2.2 解压文件

```bash
tar -zxvf  zlib-1.2.11.tar.gz 
```

#### 2.3 编译文件

由于zlib configure不支持导入$CC命令，所以只能使用export 

```bash
CROSS=/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-
export  CC=${CROSS}gcc
cd zlib-1.2.11
./configure --prefix=`pwd`/_install
make 
make install
```

#### 2.4 拷贝文件至开发板

拷贝_install 下所有文件至/usr/下

```bash
cp _install/* /usr/
```



### 3 file移植

#### 3.1下载源代码

从 ftp://ftp.astron.com/pub/file 下载源代码，比如下载file-5.38.tar.gz 。

注意此处下载时应尽量选择与编译主机版本一致的，否则在 执行第六步之后 编译会出现版本不匹配导致不能编译过的问题，错误如下，编译主机版本为5.38，而此时我下载的是最新代码

```bash
make[1]: 进入目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40”
Making all in src
make[2]: 进入目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/src”
make  all-am
make[3]: 进入目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/src”
  CC       file.o
  CCLD     file
make[3]: 离开目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/src”
make[2]: 离开目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/src”
Making all in magic
make[2]: 进入目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/magic”
Cannot use the installed version of file (5.38) to
cross-compile file 5.40
Please install file 5.40 locally first
make[2]: *** [Makefile:842：magic.mgc] 错误 1
make[2]: 离开目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40/magic”
make[1]: *** [Makefile:459：all-recursive] 错误 1
make[1]: 离开目录“/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/file-5.40”
make: *** [Makefile:368：all] 错误 2

```

#### 3.2 解压文件

```bash
tar -zxvf file-5.38.tar.gz
```

#### 3.3 configure生成配置文件

指定为交叉编译，指定为静态编译，禁用动态编译，因为开发板中没有库

```bash
CROSS=/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-
./configure --host=arm-linux --enable-static --disable-shared CC=${CROSS}gcc  AS=${CROSS}as  LD=${CROSS}ld AR=${CROSS}ar   RANLIB=${CROSS}ranlib 
```

#### 3.4 修改file-5.38/src/Makefile文件

添加--static到CFLAGS里，使用静态链接。

```makefile
CFLAGS = -g -O2 --static
```

#### 3.5 修改file-5.38/src/file.c文件

将file.c 文件中的main() 函数的 `const char *magicfile = NULL;/* where the magic is*/`

改为：

```c
const char *magicfile = "/usr/bin/magic.mgc";
```

#### 3.6 编译生成file 和MagDir拷贝至开发板

make生成file二进制文件，在src/目录下

MagDir/目录在magic/目录下

拷贝file文件和MagDir至开发板

#### 3.7 开发板使用命令生成magic.mgc文件

首先给file赋权限

```bash
chmod +x file
./file -C -m MagDir/
ls Magdir.mgc
mv Magdir.mgc magic.mgc
```

#### 3.8 拷贝命令到/usr/bin目录下

```bash
cp magic.mgc /usr/bin
cp file /usr/bin
```

#### 3.9 运行

如果显示缺少zlib库，则需交叉编译zlib，怎么编译，查看 2zlib移植

```bash
[root@$10: root]# file *
Magdir:    directory
file:      ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.3, for GNU/Linux 2.6.27, with debug_info, not stripped
magic.mgc: magic binary file for file(1) cmd (version 14) (little endian)

```



### 4 python3.9移植

#### 4.1 下载源码

打开https://www.python.org/downloads/source/，选择Latest Python 3 Release - Python 3.9.6 源码下载，点进去后找到Gzipped source tarball 或XZ compressed source tarball即可下载。

#### 4.2 解压文件

```bash
tar -zxvf Python-3.9.6.tgz
```

#### 4.3 编译

**依赖项**：

1.要保证交叉编译python3.9 需要保证本机系统中有Python3.9，否则在configure时会检测到错误。

ubuntu直接sudo apt install python3.9即可

2.依赖zlib库

3._ctypes依赖libffi库

依赖zlib和ffi库需首先交叉编译出zlib和libffi库，之后通过使用LDFLAGS和CPPFLAGS导入

```bash
CROSS=/opt/FriendlyARM/toolschain/4.5.1/bin/arm-none-linux-gnueabi-

mkdir build_arm && cd build_arm
mkdir _install 
../configure \
CC=${CROSS}gcc \
CXX=${CROSS}g++ \
AR=${CROSS}ar \
READELF=${CROSS}readelf \
--host=arm-linux \
--build=x86_64-linux-gnu \
--target=arm-linux \
--prefix=`pwd`/_install/ \
--with-ensurepip=yes \
ac_cv_file__dev_ptmx=yes \
ac_cv_file__dev_ptc=yes  \
--disable-ipv6 \
--enable-optimizations \
--with-system-ffi \
LDFLAGS="-L/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/result/zlib-1.2.11/_install/lib \
-L/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/result/libffi-3.3/_install/lib" \
CPPFLAGS="-I/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/result/zlib-1.2.11/_install/include \
-I/home/pwn/Desktop/work/share/smart210/git/smart210-SDK/3rd/result/libffi-3.3/_install/include \
"

make && make install

```



