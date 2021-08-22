#include <linux/init.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/uaccess.h>

#define LED_MAJOR 200
#define LED_NAME "led1"

//物理地址 配置J2-0 0x10
#define GPJ2CON (0xe0200280)
#define GPJ2DAT (GPJ2CON + 4)
#define GPJ2PUD (GPJ2DAT + 4)

//MMU映射的虚拟地址指针
static void __iomem *S5PV_GPJ2CON;
static void __iomem *S5PV_GPJ2DAT;
static void __iomem *S5PV_GPJ2PUD;

static int led_open(struct inode *inode, struct file *filp)
{
    return 0;
}
static int led_release(struct inode *inode, struct file *filp)
{
    return 0;
}
static ssize_t led_read(struct file *filp, __user char *buf, size_t count, loff_t *ppos)
{
    return 0;
}
static ssize_t led_write(struct file *filp, const char __user *buf, size_t count, loff_t *ppos)
{
    char writebuf[1];
    int ret = 0;
    int val = 0;
    ret = copy_from_user(writebuf, buf, count);
    if (ret < 0)
    {
        printk("kernel write failed!\r\n");
        return -EFAULT;
    }

    if (writebuf[0] == 0) //关闭
    {
        val = readl(S5PV_GPJ2DAT);
        val &= ~(0x01 << 1); /*先清除bit1以前配置*/
        val |= 0x01 << 1;    /*在配置新配置*/
        writel(val, S5PV_GPJ2DAT);
    }
    else //打开
    {
        val = readl(S5PV_GPJ2DAT);
        val &= ~(0x01 << 1); /*先清除bit1以前配置*/
        val |= 0x00 << 1;    /*在配置新配置 */
        writel(val, S5PV_GPJ2DAT);
    }
    return 0;
}

static const struct file_operations led_fops = {
    .owner = THIS_MODULE,
    .open = led_open,
    .release = led_release,
    .write = led_write,
    .read = led_read,
};

static int __init led_init(void)
{

    int ret = 0;
    int val = 0;

    /*初始化地址映射*/
    S5PV_GPJ2CON = ioremap(GPJ2CON, 4);
    S5PV_GPJ2DAT = ioremap(GPJ2DAT, 4);
    S5PV_GPJ2PUD = ioremap(GPJ2PUD, 4);

    /*初始化 LED*/
    val = readl(S5PV_GPJ2CON);
    val &= ~(0x0f << 4); /*先清除bit7-4以前配置*/
    val |= 0x01 << 4;    /*在配置新配置 0x01为输出模式*/
    writel(val, S5PV_GPJ2CON);

    val = readl(S5PV_GPJ2PUD);
    val &= ~(0x03 << 2); /*先清除bit3-2以前配置*/
    val |= 0x01 << 2;    /*在配置新配置 0x01下拉电阻*/
    writel(val, S5PV_GPJ2PUD);

    val = readl(S5PV_GPJ2DAT);
    val &= ~(0x01 << 1); /*先清除bit1以前配置*/
    val |= 0x00 << 1;    /*在配置新配置 默认输出低电平*/
    writel(val, S5PV_GPJ2DAT);

    /*1.注册字符设备*/
    ret = register_chrdev(LED_MAJOR, LED_NAME, &led_fops);
    if (ret < 0)
    {
        printk("register chardev failed!\r\n");
        return -EIO;
    }

    printk("led_init\r\n");

    return 0;
}

static void __exit led_exit(void)
{
    int val = 0;

    /*取消地址映射前，关闭该灯*/
    val = readl(S5PV_GPJ2DAT);
    val &= ~(0x01 << 1); /*先清除bit1以前配置*/
    val |= 0x01 << 1;    /*在配置新配置 默认输出低电平*/
    writel(val, S5PV_GPJ2DAT);

    /*取消地址映射*/
    iounmap(S5PV_GPJ2CON);
    iounmap(S5PV_GPJ2DAT);
    iounmap(S5PV_GPJ2PUD);

    /*注销设备*/
    unregister_chrdev(LED_MAJOR, LED_NAME);
}

module_init(led_init);
module_exit(led_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("gonglanjing");