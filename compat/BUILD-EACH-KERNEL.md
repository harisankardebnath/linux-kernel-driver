# ARM64 Linux 5.10.x device builds

The project target is ARM64 Linux **5.10.x** across vendor devices. The module basename is always:

```
reverse_exe-5.10.ko
```

## Important ABI rule

“Universal” refers to the source and naming convention, not to one interchangeable binary. Two devices running 5.10.x can have different kernel ABIs/KMIs, exported symbols, symbol CRCs, configuration, compiler flags, LTO/CFI settings, vendor backports and module-signing requirements. Build a separate module against each exact device kernel build tree.

## Required inputs per device

- Exact vendor kernel source for the installed firmware
- Prepared output/build directory for that source
- Exact `.config` and generated headers
- `Module.symvers` when symbol versioning is enabled
- Matching LLVM/GCC toolchain and build flags
- Android GKI KMI and module-signing data/policy, if applicable

## Build

```bash
./scripts/build-module.sh /path/to/device/kernel/out
```

For several devices:

```bash
./scripts/build-many-kernels.sh /kernels/device-A/out /kernels/device-B/out /kernels/device-C/out
```

Each output is kept separately:

```
artifacts/per-kernel/<exact-kernel-release>-arm64/reverse_exe-5.10.ko
```

Do not combine artifacts merely because their kernel release strings both start with 5.10. If two targets have the same release string, use separate output roots to prevent collisions:

```bash
./scripts/build-module.sh /kernels/device-A/out artifacts/device-A
./scripts/build-module.sh /kernels/device-B/out artifacts/device-B
```

## Motorola Moto G64 5G reference

Motorola publishes a matching 5.10.218 source branch here:

[Motorola kernel-mtk — android-15-release-v1tds35h.83-20-5-2](https://github.com/MotorolaMobilityLLC/kernel-mtk/tree/android-15-release-v1tds35h.83-20-5-2)

The branch Makefile reports Linux 5.10.218. Verify it against the exact firmware/build configuration on the phone before compiling and loading. Matching only the version string is insufficient.

## Validation checklist

1. Confirm target architecture is ARM64 and kernel release is 5.10.x.
2. Build against the exact prepared source/output tree.
3. Inspect `modinfo reverse_exe-5.10.ko` and verify vermagic.
4. Check unresolved symbols, symbol CRCs and GKI KMI compatibility.
5. Sign the module if the target kernel requires signed modules.
6. Load only on the matching device build and inspect `dmesg`.
7. Run `scripts/test-device.sh` to test the private buffer.

**Status:** The source is configured for the 5.10.x ARM64 target. Cross-vendor compatibility is not certified until separate device builds and load tests have passed. A successful compile does not prove runtime compatibility.
