/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef LINUX_KERNEL_DRIVER_UAPI_H
#define LINUX_KERNEL_DRIVER_UAPI_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define LKD_DEVICE_PATH "/dev/linux_kernel_driver"
#define LKD_IOC_MAGIC   'L'
#define LKD_IOC_CLEAR   _IO(LKD_IOC_MAGIC, 0)
#define LKD_IOC_SIZE    _IOR(LKD_IOC_MAGIC, 1, __u32)

#endif
