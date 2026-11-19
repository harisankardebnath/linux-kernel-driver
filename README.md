# Linux Kernel Driver — Android GKI workspace

This repository contains a diagnostic Linux character-device module and scripts/workflows for fetching and building Android Common Kernel (ACK/GKI) source branches for ARM64.

## Scope and safety

The module exposes `/dev/linux_kernel_driver` and provides bounded read/write access only to its own private 4 KiB test buffer, plus clear and size ioctls. It does not read or write another process's memory, physical memory, or arbitrary kernel memory. It contains no process-hiding or anti-cheat functionality.

## Kernel source branches

- Linux 5.10: `common-android13-5.10`
- Linux 5.15: `common-android14-5.15`
- Linux 6.1: `common-android14-6.1`

Full Google kernel source trees are fetched separately by the scripts; they are not vendored in this repository. A successful generic GKI build does not imply compatibility with every phone. The Moto G64 5G requires matching Motorola/vendor sources, KMI, configuration, vendor modules and signing policy. Do not flash an image without verifying it for the exact device and firmware.

See `driver/`, `scripts/` and `.github/workflows/` for the implementation and build process. Build jobs require substantial disk space and RAM, and must be checked before treating their outputs as device-ready.

## Separate module for each exact kernel version

The project now includes a per-kernel build path. Use `scripts/build-module.sh <prepared-kernel-build-tree>` once for each exact kernel build. Each successful run creates a differently named artifact such as `linux_kernel_driver-<kernelrelease>-arm64.ko` under `artifacts/per-kernel/`. To build several kernels, pass all prepared build directories to `scripts/build-many-kernels.sh`.

The target range is Linux 4.14 through the latest kernel source supplied to the build system. The listed kernel families are planned targets, not prebuilt or tested releases. A separate exact source/configuration is required for each build; version numbers alone are insufficient, especially for OEM Android kernels. See `compat/BUILD-EACH-KERNEL.md`.
