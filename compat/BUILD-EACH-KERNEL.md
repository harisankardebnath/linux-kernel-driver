# Build reverse_exe across Linux 4.4.x–6.1.x

The intended kernel source-compatibility range is Linux **4.4.x through 6.1.x inclusive**. Target families: 4.4, 4.9, 4.14, 4.19, 5.4, 5.10, 5.15 and 6.1.

Prepare a separate configured kernel source/output tree for every exact target build. Each tree must have its matching .config, generated headers, and Module.symvers when CONFIG_MODVERSIONS is enabled. Use the exact toolchain and vendor source/configuration for that target.

Example builds:

```bash
./scripts/build-module.sh /kernels/4.4/out
./scripts/build-module.sh /kernels/4.9/out
./scripts/build-module.sh /kernels/4.14/out
./scripts/build-module.sh /kernels/4.19/out
./scripts/build-module.sh /kernels/5.4/out
./scripts/build-module.sh /kernels/5.10/out
./scripts/build-module.sh /kernels/5.15/out
./scripts/build-module.sh /kernels/6.1/out
```

The artifact name is the kernel family: a build from 5.10.218 produces `reverse_exe-5.10.ko`; a build from 6.1.75 produces `reverse_exe-6.1.ko`. Exact patch/vendor release metadata is stored alongside each artifact in its own full-release directory.

Build multiple prepared trees in one run:

```bash
./scripts/build-many-kernels.sh /kernels/4.4/out /kernels/4.9/out /kernels/4.14/out /kernels/4.19/out /kernels/5.4/out /kernels/5.10/out /kernels/5.15/out /kernels/6.1/out
```

**Testing status:** The range is the intended compatibility target, not proof that every patch release, OEM fork or configuration has passed build/load testing. Current GitHub Actions covers ACK 5.10, 5.15 and 6.1 only. Legacy 4.4 through 5.4 trees must be supplied as exact source/output trees and built separately. A successful compile does not prove load-time ABI, KMI, signing or device compatibility.
