# Kernel compatibility policy

## Target range

The project target is **Linux 4.14 through the newest kernel release available at build time**, on ARM64. This is a compatibility target, not a claim that one binary module works on every kernel.

Linux kernel modules are tied to the exact kernel build, configuration, symbol versions, exported symbols, and (on Android) the vendor/GKI KMI and module-signing policy. Build a separate module for each target kernel. Never reuse a .ko built for a different device/kernel unless the kernel ABI is known to match.

## Version families to validate

| Kernel family | Status in this repository |
| --- | --- |
| 4.14, 4.19 | Target; not yet build-tested |
| 5.4 | Target; not yet build-tested |
| 5.10, 5.15 | GKI build recipes present; not yet build-tested |
| 6.1, 6.6, 6.12 | Target; not yet build-tested |
| Newer stable/mainline | Target; requires fresh headers/source and compatibility review |

The above is a validation plan, not a tested compatibility claim. GitHub Actions currently contains the three Android Common Kernel GKI branches documented in the root README. It does not automatically build every upstream version.

## API compatibility

The current diagnostic driver uses long-lived character-device, mutex, uaccess, and simple-buffer helpers. It contains a class_create() signature switch for kernels before and after Linux 6.4. Other API/configuration differences may still require version-specific changes.

When adding compatibility code:
1. Prefer feature/configuration checks over guessing from LINUX_VERSION_CODE when vendor trees backport APIs.
2. Keep version-specific code isolated in compat/.
3. Build against the exact target kernel tree and .config.
4. Verify Module.symvers, CONFIG_MODVERSIONS, GKI KMI constraints, module signing, and required vendor interfaces.
5. Record build logs and the exact source commit/configuration for each successful build.

## Android device warning

A generic upstream or ACK/GKI build is not a drop-in replacement for an OEM device kernel. For a Motorola Moto G64 5G, the exact Motorola kernel source, vendor modules, KMI, defconfig, toolchain, boot image layout, AVB/signing, and firmware revision must be matched. This repository does not flash kernels or guarantee device bootability.

## Scope

This is a diagnostic character driver with a private bounded 4 KiB buffer. It does not inspect or modify other processes, games, physical memory, or arbitrary kernel memory. It has no stealth or anti-cheat bypass functionality.
