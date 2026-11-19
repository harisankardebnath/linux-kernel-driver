// SPDX-License-Identifier: GPL-2.0
#ifndef VANTEX_CLIENT_H
#define VANTEX_CLIENT_H

/*
 * VANTEX client API for the VANTEX kernel module's explicit
 * /dev/reverse_exe private test-buffer interface.
 *
 * This header supports only this VANTEX device ABI. It does not probe
 * alternate driver nodes, attach to processes, or access process memory.
 */

#include <cerrno>
#include <cstdint>
#include <cstddef>
#include <string>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>

#define VANTEX_DEVICE_PATH       "/dev/reverse_exe"
#define VANTEX_BUFFER_CAPACITY   4096u
#define VANTEX_IOC_MAGIC         'R'
#define VANTEX_IOC_CLEAR         _IO(VANTEX_IOC_MAGIC, 0)
#define VANTEX_IOC_SIZE          _IOR(VANTEX_IOC_MAGIC, 1, std::uint32_t)

class VantexClient {
public:
    VantexClient() = default;
    ~VantexClient() { disconnect(); }

    VantexClient(const VantexClient&) = delete;
    VantexClient& operator=(const VantexClient&) = delete;

    bool connect(const char* path = VANTEX_DEVICE_PATH) {
        disconnect();
        if (!path || !*path) {
            errno = EINVAL;
            return false;
        }
        fd_ = ::open(path, O_RDWR | O_CLOEXEC);
        return fd_ >= 0;
    }

    void disconnect() {
        if (fd_ >= 0) {
            ::close(fd_);
            fd_ = -1;
        }
    }

    bool connected() const { return fd_ >= 0; }
    int native_handle() const { return fd_; }

    // Writes bytes into the module's bounded private test buffer.
    // The kernel module enforces the final bounds as well.
    ssize_t write_buffer(const void* data, std::size_t size) {
        if (fd_ < 0) { errno = ENOTCONN; return -1; }
        if ((!data && size != 0) || size > VANTEX_BUFFER_CAPACITY) {
            errno = EINVAL;
            return -1;
        }
        return ::pwrite(fd_, data, size, 0);
    }

    // Reads bytes from the module's bounded private test buffer.
    ssize_t read_buffer(void* data, std::size_t size) {
        if (fd_ < 0) { errno = ENOTCONN; return -1; }
        if ((!data && size != 0) || size > VANTEX_BUFFER_CAPACITY) {
            errno = EINVAL;
            return -1;
        }
        return ::pread(fd_, data, size, 0);
    }

    bool clear_buffer() {
        if (fd_ < 0) { errno = ENOTCONN; return false; }
        return ::ioctl(fd_, VANTEX_IOC_CLEAR) == 0;
    }

    bool buffer_size(std::uint32_t& size) const {
        if (fd_ < 0) { errno = ENOTCONN; return false; }
        return ::ioctl(fd_, VANTEX_IOC_SIZE, &size) == 0;
    }

private:
    int fd_ = -1;
};

#endif // VANTEX_CLIENT_H
