#ifndef VANTEX_DRIVER_H
#define VANTEX_DRIVER_H

/*
 * VANTEX userspace client for the kernel module's bounded private test buffer.
 * This API only accesses the module's private 4 KiB buffer. It deliberately
 * has no PID/address-based process, game, physical, or kernel memory API.
 */
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include "driver/driver_uapi.h"

class vantex_driver {
public:
    vantex_driver() noexcept : fd_(-1) {}
    ~vantex_driver() { close_device(); }

    vantex_driver(const vantex_driver&) = delete;
    vantex_driver& operator=(const vantex_driver&) = delete;

    vantex_driver(vantex_driver&& other) noexcept : fd_(other.fd_) {
        other.fd_ = -1;
    }

    vantex_driver& operator=(vantex_driver&& other) noexcept {
        if (this != &other) {
            close_device();
            fd_ = other.fd_;
            other.fd_ = -1;
        }
        return *this;
    }

    bool open_device(const char* path = REVERSE_EXE_DEVICE_PATH) {
        if (fd_ >= 0 || path == nullptr) {
            errno = (fd_ >= 0) ? EALREADY : EINVAL;
            return false;
        }
        fd_ = ::open(path, O_RDWR | O_CLOEXEC);
        return fd_ >= 0;
    }

    void close_device() noexcept {
        if (fd_ >= 0) {
            const int saved_errno = errno;
            (void)::close(fd_);
            fd_ = -1;
            errno = saved_errno;
        }
    }

    bool is_open() const noexcept { return fd_ >= 0; }

    bool read_buffer(void* output, std::size_t length, off_t offset = 0) const {
        if (!valid_range(output, length, offset) || !seek(offset))
            return false;
        return transfer_read(output, length);
    }

    bool write_buffer(const void* input, std::size_t length,
                      off_t offset = 0) const {
        if (!valid_range(input, length, offset) || !seek(offset))
            return false;
        return transfer_write(input, length);
    }

    bool clear() const {
        if (fd_ < 0) {
            errno = EBADF;
            return false;
        }
        return ::ioctl(fd_, REVERSE_EXE_IOC_CLEAR) == 0;
    }

    /* Returns current logical data length (0..4096), not buffer capacity. */
    bool size(std::uint32_t& result) const {
        if (fd_ < 0) {
            errno = EBADF;
            return false;
        }
        __u32 value = 0;
        if (::ioctl(fd_, REVERSE_EXE_IOC_SIZE, &value) != 0)
            return false;
        result = value;
        return true;
    }

private:
    int fd_;

    static bool valid_range(const void* ptr, std::size_t length, off_t offset) {
        if (ptr == nullptr && length != 0) {
            errno = EINVAL;
            return false;
        }
        if (offset < 0 || static_cast<std::uint64_t>(offset) >
                              REVERSE_EXE_BUFFER_SIZE ||
            length > REVERSE_EXE_BUFFER_SIZE -
                         static_cast<std::size_t>(offset)) {
            errno = ERANGE;
            return false;
        }
        return true;
    }

    bool seek(off_t offset) const {
        if (fd_ < 0) {
            errno = EBADF;
            return false;
        }
        return ::lseek(fd_, offset, SEEK_SET) == offset;
    }

    bool transfer_read(void* output, std::size_t length) const {
        if (fd_ < 0) {
            errno = EBADF;
            return false;
        }
        std::size_t done = 0;
        while (done < length) {
            const ssize_t n = ::read(fd_, static_cast<char*>(output) + done,
                                     length - done);
            if (n < 0 && errno == EINTR)
                continue;
            if (n <= 0) {
                if (n == 0) errno = EIO;
                return false;
            }
            done += static_cast<std::size_t>(n);
        }
        return true;
    }

    bool transfer_write(const void* input, std::size_t length) const {
        if (fd_ < 0) {
            errno = EBADF;
            return false;
        }
        std::size_t done = 0;
        while (done < length) {
            const ssize_t n = ::write(fd_,
                                      static_cast<const char*>(input) + done,
                                      length - done);
            if (n < 0 && errno == EINTR)
                continue;
            if (n <= 0) {
                if (n == 0) errno = EIO;
                return false;
            }
            done += static_cast<std::size_t>(n);
        }
        return true;
    }
};

#endif /* VANTEX_DRIVER_H */
