# reverse_exe — Android/Linux kernel diagnostic driver

**Target kernel range:** Linux 4.4.x through 6.1.x  
**Module filename pattern:** `reverse_exe-<major>.<minor>.<patch>.ko`  
**Examples:** `reverse_exe-4.4.x.ko`, `reverse_exe-5.10.x.ko`, `reverse_exe-6.1.x.ko`  
**Device node:** `/dev/reverse_exe`

## Scope

This is a diagnostic character driver exposing a private bounded 4 KiB buffer with read/write, clear and size ioctl operations. It does not read or write other processes' memory, game memory, physical memory, or arbitrary kernel memory. It contains no anti-cheat bypass, process hiding, or stealth features.

## Kernel compatibility target

The intended source-compatibility range is Linux **4.4.x to 6.1.x inclusive**. Target families include 4.4, 4.9, 4.14, 4.19, 5.4, 5.10, 5.15 and 6.1. This is a compatibility target, not a claim that every patch release or vendor kernel has already been built and tested. Vendor backports and configuration differences can require fixes for an individual tree.

Build a separate module for every exact prepared kernel build tree:

```bash
./scripts/build-module.sh /path/to/prepared/kernel/build
```

For multiple exact builds:

```bash
./scripts/build-many-kernels.sh /kernels/4.4.x/out /kernels/4.9.x/out /kernels/4.14.x/out /kernels/4.19.x/out /kernels/5.4.x/out /kernels/5.10.x/out /kernels/5.15.x/out /kernels/6.1.x/out
```

The resulting artifact filename uses the exact numeric patch release reported by Kbuild, for example `reverse_exe-5.10.218.ko`. Full release/build metadata is kept in a separate directory so OEM builds do not overwrite one another.

A kernel version alone does not guarantee ABI compatibility. Each module must be built against the matching source, configuration, generated headers, Module.symvers when applicable, and matching toolchain. Android GKI KMI and module-signing requirements also apply. Never assume one compiled .ko works on every kernel in the range.

## CI workflow

The GitHub Actions workflow currently provides manual Android Common Kernel builds for 5.10, 5.15 and 6.1. It does not automatically cover legacy 4.4 through 5.4 trees or every OEM kernel. Use `scripts/build-many-kernels.sh` with each exact prepared source/output tree for those targets.

## Motorola Moto G64 5G

For the Moto G64, use the matching Motorola kernel source and exact firmware configuration. A generic ACK/GKI module is not automatically compatible. Do not load or flash an artifact unless the kernel release, ABI/KMI, symbol versions and signing requirements match the running device.

See `compat/BUILD-EACH-KERNEL.md` for build instructions.
