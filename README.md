# reverse_exe — ARM64 Linux 5.10 diagnostic driver

**Target:** ARM64 devices running Linux **5.10.x**  
**Module filename:** `reverse_exe-5.10.ko`  
**Device node:** `/dev/reverse_exe`

## What “universal 5.10 support” means

The source is intended to be portable across ARM64 vendor kernels based on Linux 5.10.x (Qualcomm, MediaTek, Samsung/Exynos and other ARM64 platforms). The output basename is always `reverse_exe-5.10.ko`.

**There is no single binary that is guaranteed to load on every 5.10.x device.** Vendor kernels can differ in exported symbols, symbol CRCs, GKI KMI, configuration, compiler/toolchain, LTO/CFI settings, module signing and vendor backports. Therefore build the same source separately against each exact device kernel build tree. The resulting files retain the same basename but are stored in separate directories named after their exact kernel release and build identity. Do not overwrite or mix these builds.

## Driver scope

This is a diagnostic character driver exposing a private bounded 4 KiB buffer with read/write, clear and size ioctl operations. It does not read or write other processes' memory, game memory, physical memory, or arbitrary kernel memory. It contains no anti-cheat bypass, process hiding, or stealth features.

## Requirements for each device build

- ARM64 kernel source and prepared output/build tree for that exact device firmware
- Kernel release in the 5.10.x family
- Matching `.config`, generated headers and `Module.symvers` (when applicable)
- Matching compiler/toolchain and build flags
- Matching Android GKI KMI and module-signing requirements, where enabled

## Build one device-specific module

```bash
./scripts/build-module.sh /path/to/device/kernel/out
```

The output is stored under:

```
artifacts/per-kernel/<exact-kernel-release>-arm64/reverse_exe-5.10.ko
```

For multiple devices, pass each device's own prepared build tree:

```bash
./scripts/build-many-kernels.sh /kernels/device-A/out /kernels/device-B/out /kernels/device-C/out
```

Each device build is isolated in its own exact-release directory. If two devices report the same kernel release but have different configurations or symbol tables, keep their build trees and artifacts separate; the release string alone is not a unique ABI identifier.

## Build for Motorola Moto G64 5G

The Motorola kernel source branch matching the reported 5.10.218 family is:

[MotorolaMobilityLLC/kernel-mtk — android-15-release-v1tds35h.83-20-5-2](https://github.com/MotorolaMobilityLLC/kernel-mtk/tree/android-15-release-v1tds35h.83-20-5-2)

Its top-level Makefile identifies Linux 5.10.218. Confirm the exact source commit, firmware branch, defconfig/fragments, generated output tree and toolchain against the device before loading a module. A source branch match is not by itself proof of ABI/KMI compatibility.

## Validation

A successful compile is only the first check. Before loading, verify the module's `vermagic`, architecture, symbol dependencies/versions, GKI KMI compatibility and signing policy against the target device. Test on a recoverable device setup and retain a known-good boot image. Never assume a module built for one vendor's 5.10 kernel will load on another vendor's 5.10 kernel.

The current CI workflow is a baseline build against Android Common Kernel 5.10. It is not a cross-vendor certification matrix. Device-specific builds must use each vendor's exact source/output tree.
