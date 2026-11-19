# reverse_exe — Android/Linux kernel diagnostic driver

**Module release:** 2.0.0  
**Module filename pattern:** `reverse_exe-5.10.x.ko` for the Linux 5.10 series  
**Device node:** `/dev/reverse_exe`

## Scope

This is a diagnostic character driver exposing a private bounded 4 KiB buffer with read/write, clear and size ioctl operations. It does not read or write other processes' memory, game memory, physical memory, or arbitrary kernel memory. It contains no anti-cheat bypass, process hiding, or stealth features.

## Per-kernel builds

Build a separate module for each exact prepared kernel build tree:

```bash
./scripts/build-module.sh /path/to/prepared/kernel/build
```

For several kernels:

```bash
./scripts/build-many-kernels.sh /kernels/5.10.218/out /kernels/5.10.219/out /kernels/5.10.220/out
```

For a 5.10.218 target, the module filename is `reverse_exe-5.10.218.ko`; for 5.10.219 it is `reverse_exe-5.10.219.ko`. Each artifact is stored in a directory named after the full exact kernel release so that OEM builds with the same numeric version do not overwrite one another.

A kernel version alone does not guarantee ABI compatibility. Each module must be built against the matching source, configuration, generated headers, Module.symvers, compiler and Android KMI/signing policy. Never assume one compiled .ko works on every 5.10.x device.

## Current Android Common Kernel workflow

GitHub Actions currently has manual build targets for ACK branches 5.10, 5.15 and 6.1. This is not a complete build matrix for every upstream version or OEM device. Other releases require their own exact prepared kernel source/build tree.

## Motorola Moto G64 5G

For the Moto G64, use the matching Motorola kernel source and exact firmware configuration. A generic ACK/GKI module is not automatically compatible. Do not load or flash an artifact unless the kernel release, ABI/KMI, symbol versions and signing requirements match the running device.

See `compat/BUILD-EACH-KERNEL.md` for build instructions.
