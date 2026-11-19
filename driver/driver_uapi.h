/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef REVERSE_EXE_UAPI_H
#define REVERSE_EXE_UAPI_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define REVERSE_EXE_DEVICE_PATH "/dev/reverse_exe"
#define REVERSE_EXE_IOC_MAGIC   'R'
#define REVERSE_EXE_IOC_CLEAR   _IO(REVERSE_EXE_IOC_MAGIC, 0)
#define REVERSE_EXE_IOC_SIZE    _IOR(REVERSE_EXE_IOC_MAGIC, 1, __u32)

#endif
