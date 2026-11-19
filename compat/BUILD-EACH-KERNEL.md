# Build reverse_exe across Linux 4.4.x–6.1.x

The project's intended kernel source-compatibility range is Linux **4.4.x through 6.1.x inclusive**. The target families are 4.4, 4.9, 4.14, 4.19, 5.4, 5.10, 5.15 and 6.1.

Prepare a separate configured kernel source/output tree for every exact target build. Each tree must have its matching .config, generated headers, and Module.symvers when CONFIG_MODVERSIONS is enabled. Use the exact toolchain and vendor source/configuration for that target.

Example builds:

```bash
./scripts/build-module.sh /kernels/4.4.x/out
./scripts/build-module.sh /kernels/4.9.x/out
./scripts/build-module.sh /kernels/4.14.x/out
./scripts/build-module.sh /kernels/4.19.x/out
./scripts/build-module.sh /kernels/5.4.x/out
./scripts/build-module.sh /kernels/5.10.x/out
./scripts/build-module.sh /kernels/5.15.x/out
./scripts/build-module.sh /kernels/6.1.x/out
```

The actual filename is derived from the exact Kbuild kernel release. For example, a 5.10.218 build produces `reverse_exe-5.10.218.ko`, and a 6.1.75 build produces `reverse_exe-6.1.75.ko`.

Build multiple prepared trees in one run:

```bash
./scripts/build-many-kernels.sh /kernels/4.4.x/out /kernels/4.9.x/out /kernels/4.14.x/out /kernels/4.19.x/out /kernels/5.4.x/out /kernels/5.10.x/out /kernels/5.15.x/out /kernels/6.1.x/out
```

Each successful build is stored in `artifacts/per-kernel/<full-kernel-release>-arm64/`. The filename uses the numeric major.minor.patch version; the directory and metadata preserve the full release to prevent collisions between OEM builds.

**Testing status:** The range is the intended compatibility target; it is not evidence that every patch release, OEM fork, or configuration has passed a build/load test. The current GitHub Actions workflow covers ACK 5.10, 5.15 and 6.1 only. Legacy 4.4 through 5.4 trees must be supplied as exact source/output trees and built separately. A successful compile does not prove load-time ABI, KMI, signing, or device compatibility.
