// SPDX-License-Identifier: GPL-2.0
/*
 * reverse_exe - GKI diagnostic module
 *
 * This module exposes only a private, bounded test buffer at
 * /dev/reverse_exe. It does not access another process, physical
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

#define REVERSE_EXE_NAME        "reverse_exe"
#define REVERSE_EXE_BUFFER_SIZE 4096
#define REVERSE_EXE_IOC_MAGIC   'R'
#define REVERSE_EXE_IOC_CLEAR   _IO(REVERSE_EXE_IOC_MAGIC, 0)
#define REVERSE_EXE_IOC_SIZE    _IOR(REVERSE_EXE_IOC_MAGIC, 1, __u32)

static dev_t reverse_exe_dev;
static struct cdev reverse_exe_cdev;
static struct class *reverse_exe_class;
static struct device *reverse_exe_device;

static DEFINE_MUTEX(reverse_exe_lock);
static u8 reverse_exe_buffer[REVERSE_EXE_BUFFER_SIZE];
static size_t reverse_exe_length;

static ssize_t reverse_exe_read(struct file *file, char __user *buf,
                        size_t count, loff_t *ppos)
{
    ssize_t ret;

    if (mutex_lock_interruptible(&reverse_exe_lock))
        return -ERESTARTSYS;

    ret = simple_read_from_buffer(buf, count, ppos,
                                  reverse_exe_buffer, reverse_exe_length);
    mutex_unlock(&reverse_exe_lock);
    return ret;
}

static ssize_t reverse_exe_write(struct file *file, const char __user *buf,
                         size_t count, loff_t *ppos)
{
    ssize_t ret;

    if (count > REVERSE_EXE_BUFFER_SIZE)
        return -E2BIG;

    if (mutex_lock_interruptible(&reverse_exe_lock))
        return -ERESTARTSYS;

    ret = simple_write_to_buffer(reverse_exe_buffer, sizeof(reverse_exe_buffer),
                                 ppos, buf, count);
    if (ret > 0 && *ppos > reverse_exe_length)
        reverse_exe_length = *ppos;

    mutex_unlock(&reverse_exe_lock);
    return ret;
}

static long reverse_exe_ioctl(struct file *file, unsigned int cmd,
                      unsigned long arg)
{
    __u32 size;

    if (_IOC_TYPE(cmd) != REVERSE_EXE_IOC_MAGIC)
        return -ENOTTY;

    switch (cmd) {
    case REVERSE_EXE_IOC_CLEAR:
        if (mutex_lock_interruptible(&reverse_exe_lock))
            return -ERESTARTSYS;
        memset(reverse_exe_buffer, 0, sizeof(reverse_exe_buffer));
        reverse_exe_length = 0;
        mutex_unlock(&reverse_exe_lock);
        return 0;

    case REVERSE_EXE_IOC_SIZE:
        if (mutex_lock_interruptible(&reverse_exe_lock))
            return -ERESTARTSYS;
        size = (__u32)reverse_exe_length;
        mutex_unlock(&reverse_exe_lock);
        return copy_to_user((__u32 __user *)arg, &size, sizeof(size))
                   ? -EFAULT : 0;

    default:
        return -ENOTTY;
    }
}

static const struct file_operations reverse_exe_fops = {
    .owner          = THIS_MODULE,
    .read           = reverse_exe_read,
    .write          = reverse_exe_write,
    .unlocked_ioctl = reverse_exe_ioctl,
    .llseek         = default_llseek,
};

static int __init reverse_exe_init(void)
{
    int ret;

    ret = alloc_chrdev_region(&reverse_exe_dev, 0, 1, REVERSE_EXE_NAME);
    if (ret)
        return ret;

    cdev_init(&reverse_exe_cdev, &reverse_exe_fops);
    reverse_exe_cdev.owner = THIS_MODULE;

    ret = cdev_add(&reverse_exe_cdev, reverse_exe_dev, 1);
    if (ret)
        goto err_unregister;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
    reverse_exe_class = class_create(REVERSE_EXE_NAME);
#else
    reverse_exe_class = class_create(THIS_MODULE, REVERSE_EXE_NAME);
#endif
    if (IS_ERR(reverse_exe_class)) {
        ret = PTR_ERR(reverse_exe_class);
        goto err_cdev;
    }

    reverse_exe_device = device_create(reverse_exe_class, NULL, reverse_exe_dev, NULL, REVERSE_EXE_NAME);
    if (IS_ERR(reverse_exe_device)) {
        ret = PTR_ERR(reverse_exe_device);
        goto err_class;
    }

    pr_info(REVERSE_EXE_NAME ": loaded; buffer=%u bytes; major=%u minor=%u\n",
            REVERSE_EXE_BUFFER_SIZE, MAJOR(reverse_exe_dev), MINOR(reverse_exe_dev));
    return 0;

err_class:
    class_destroy(reverse_exe_class);
err_cdev:
    cdev_del(&reverse_exe_cdev);
err_unregister:
    unregister_chrdev_region(reverse_exe_dev, 1);
    return ret;
}

static void __exit reverse_exe_exit(void)
{
    device_destroy(reverse_exe_class, reverse_exe_dev);
    class_destroy(reverse_exe_class);
    cdev_del(&reverse_exe_cdev);
    unregister_chrdev_region(reverse_exe_dev, 1);
    pr_info(REVERSE_EXE_NAME ": unloaded\n");
}

module_init(reverse_exe_init);
module_exit(reverse_exe_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("reverse_exe Project");
MODULE_DESCRIPTION("reverse_exe diagnostic character driver with private test-buffer I/O");
MODULE_VERSION("2.0.0");
