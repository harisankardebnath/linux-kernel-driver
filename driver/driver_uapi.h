/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef REVERSE_EXE_UAPI_H
#define REVERSE_EXE_UAPI_H

/*
 * Shared userspace/kernel ABI for the bounded reverse_exe diagnostic device.
 *
 * The device exposes only its own private 4 KiB test buffer. It does not
 * accept PID/address pairs and provides no process/game/physical/kernel
 * memory access or hiding functionality.
 */
#ifdef __KERNEL__
#include <linux/ioctl.h>
#include <linux/types.h>
#else
#include <stdint.h>
#include <sys/ioctl.h>
typedef uint32_t __u32;
#endif

#define REVERSE_EXE_DEVICE_PATH   "/dev/reverse_exe"
#define REVERSE_EXE_BUFFER_SIZE  4096U
#define REVERSE_EXE_IOC_MAGIC    'R'

/* Clear the complete private buffer and reset its logical length to zero. */
#define REVERSE_EXE_IOC_CLEAR    _IO(REVERSE_EXE_IOC_MAGIC, 0)

/* Copy the current logical data length (not capacity) to a userspace __u32. */
#define REVERSE_EXE_IOC_SIZE     _IOR(REVERSE_EXE_IOC_MAGIC, 1, __u32)

#endif /* REVERSE_EXE_UAPI_H */
