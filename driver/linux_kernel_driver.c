// SPDX-License-Identifier: GPL-2.0
/*
 * Linux Kernel Driver - GKI diagnostic module
 *
 * This module exposes only a private, bounded test buffer at
 * /dev/linux_kernel_driver. It does not access another process, physical
 * memory, kernel memory, or game memory.
 */
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/ioctl.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <linux/version.h>

#define LKD_NAME        "linux_kernel_driver"
#define LKD_BUFFER_SIZE 4096
#define LKD_IOC_MAGIC   'L'
#define LKD_IOC_CLEAR   _IO(LKD_IOC_MAGIC, 0)
#define LKD_IOC_SIZE    _IOR(LKD_IOC_MAGIC, 1, __u32)

static dev_t lkd_dev;
static struct cdev lkd_cdev;
static struct class *lkd_class;
static struct device *lkd_device;

static DEFINE_MUTEX(lkd_lock);
static u8 lkd_buffer[LKD_BUFFER_SIZE];
static size_t lkd_length;

static ssize_t lkd_read(struct file *file, char __user *buf,
                        size_t count, loff_t *ppos)
{
    ssize_t ret;

    if (mutex_lock_interruptible(&lkd_lock))
        return -ERESTARTSYS;

    ret = simple_read_from_buffer(buf, count, ppos,
                                  lkd_buffer, lkd_length);
    mutex_unlock(&lkd_lock);
    return ret;
}

static ssize_t lkd_write(struct file *file, const char __user *buf,
                         size_t count, loff_t *ppos)
{
    ssize_t ret;

    if (count > LKD_BUFFER_SIZE)
        return -E2BIG;

    if (mutex_lock_interruptible(&lkd_lock))
        return -ERESTARTSYS;

    ret = simple_write_to_buffer(lkd_buffer, sizeof(lkd_buffer),
                                 ppos, buf, count);
    if (ret > 0 && *ppos > lkd_length)
        lkd_length = *ppos;

    mutex_unlock(&lkd_lock);
    return ret;
}

static long lkd_ioctl(struct file *file, unsigned int cmd,
                      unsigned long arg)
{
    __u32 size;

    if (_IOC_TYPE(cmd) != LKD_IOC_MAGIC)
        return -ENOTTY;

    switch (cmd) {
    case LKD_IOC_CLEAR:
        if (mutex_lock_interruptible(&lkd_lock))
            return -ERESTARTSYS;
        memset(lkd_buffer, 0, sizeof(lkd_buffer));
        lkd_length = 0;
        mutex_unlock(&lkd_lock);
        return 0;

    case LKD_IOC_SIZE:
        if (mutex_lock_interruptible(&lkd_lock))
            return -ERESTARTSYS;
        size = (__u32)lkd_length;
        mutex_unlock(&lkd_lock);
        return copy_to_user((__u32 __user *)arg, &size, sizeof(size))
                   ? -EFAULT : 0;

    default:
        return -ENOTTY;
    }
}

static const struct file_operations lkd_fops = {
    .owner          = THIS_MODULE,
    .read           = lkd_read,
    .write          = lkd_write,
    .unlocked_ioctl = lkd_ioctl,
    .llseek         = default_llseek,
};

static int __init lkd_init(void)
{
    int ret;

    ret = alloc_chrdev_region(&lkd_dev, 0, 1, LKD_NAME);
    if (ret)
        return ret;

    cdev_init(&lkd_cdev, &lkd_fops);
    lkd_cdev.owner = THIS_MODULE;

    ret = cdev_add(&lkd_cdev, lkd_dev, 1);
    if (ret)
        goto err_unregister;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
    lkd_class = class_create(LKD_NAME);
#else
    lkd_class = class_create(THIS_MODULE, LKD_NAME);
#endif
    if (IS_ERR(lkd_class)) {
        ret = PTR_ERR(lkd_class);
        goto err_cdev;
    }

    lkd_device = device_create(lkd_class, NULL, lkd_dev, NULL, LKD_NAME);
    if (IS_ERR(lkd_device)) {
        ret = PTR_ERR(lkd_device);
        goto err_class;
    }

    pr_info(LKD_NAME ": loaded; buffer=%u bytes; major=%u minor=%u\n",
            LKD_BUFFER_SIZE, MAJOR(lkd_dev), MINOR(lkd_dev));
    return 0;

err_class:
    class_destroy(lkd_class);
err_cdev:
    cdev_del(&lkd_cdev);
err_unregister:
    unregister_chrdev_region(lkd_dev, 1);
    return ret;
}

static void __exit lkd_exit(void)
{
    device_destroy(lkd_class, lkd_dev);
    class_destroy(lkd_class);
    cdev_del(&lkd_cdev);
    unregister_chrdev_region(lkd_dev, 1);
    pr_info(LKD_NAME ": unloaded\n");
}

module_init(lkd_init);
module_exit(lkd_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Linux Kernel Driver Project");
MODULE_DESCRIPTION("GKI diagnostic character driver with private test-buffer I/O");
MODULE_VERSION("1.0");
