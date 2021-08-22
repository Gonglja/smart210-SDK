#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/uaccess.h>

#define CHRDEVBASE_MAJOR 200
#define CHRDEVBASE_MINOR 0
#define CHRDEVBASE_NAME "chrdevbase"

static char readbuff[100];
static char writebuff[100];
static char kerneldata[] = {"kernel data."};

static int chrdevbase_open(struct inode *inode, struct file *filp)
{
    printk("chrdevbase_open\r\n");
    return 0;
}

static int chrdevbase_release(struct inode *inode, struct file *filp)
{
    printk("chrdevbase_release\r\n");
    return 0;
}

static ssize_t chrdevbase_read(struct file *filp, __user char *buf,
                               size_t count, loff_t *ppos)
{
    int ret = 0;
    printk("chrdevbase_read\r\n");
    memcpy(readbuff, kerneldata, sizeof(kerneldata));
    ret = copy_to_user(buf, readbuff, count);
    if (ret == 0)
    {
    }
    else
    {
        ;
    }

    return 0;
}

static ssize_t chrdevbase_write(struct file *filp, const char __user *buf,
                                size_t count, loff_t *ppos)
{
    int ret = 0;
    printk("chrdevbase_write\r\n");
    ret = copy_from_user(writebuff, buf, count);
    if (ret == 0)
    {
        printk("kernel recvdata:%s\r\n", writebuff);
    }
    else
    {
        ;
    }
    return 0;
}

static struct file_operations chedevbase_fops = {
    .owner = THIS_MODULE,
    .open = chrdevbase_open,
    .release = chrdevbase_release,
    .read = chrdevbase_read,
    .write = chrdevbase_write,
};

static int __init chrdevbase_init(void)
{
    int ret = 0;
    printk("chrdevbase init.\r\n");
    /*注册字符设备*/
    ret = register_chrdev(CHRDEVBASE_MAJOR, CHRDEVBASE_NAME, &chedevbase_fops); //将一个主设备号下的所有次设备号使用了，所以一般不用他,这里为了练习继续使用
    // register_chrdev_region();

    if (ret < 0)
        printk("chrdevbase init failed!\r\n");
    return 0;
}

static void __exit chrdevbase_exit(void)
{
    printk("chrdevbase exit.\r\n");
    /*注销字符设备*/
    unregister_chrdev(CHRDEVBASE_MAJOR, CHRDEVBASE_NAME);
}

/**
 * 模块入口与出口
 */
module_init(chrdevbase_init); /*入口*/
module_exit(chrdevbase_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("gonglanjing");