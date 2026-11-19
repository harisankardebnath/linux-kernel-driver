# Build a separate .ko for each kernel

Prepare a separate kernel source/output tree for every exact target kernel. Each must have its matching .config, generated headers, and Module.symvers when CONFIG_MODVERSIONS is enabled.

Examples:

```bash
./scripts/build-module.sh /kernels/4.14/out
./scripts/build-module.sh /kernels/4.19/out
./scripts/build-module.sh /kernels/5.4/out
./scripts/build-module.sh /kernels/5.10/out
./scripts/build-module.sh /kernels/5.15/out
./scripts/build-module.sh /kernels/6.1/out
./scripts/build-module.sh /kernels/6.6/out
./scripts/build-module.sh /kernels/6.12/out
```

Or build several exact trees in one run:

```bash
./scripts/build-many-kernels.sh /kernels/4.14/out /kernels/4.19/out /kernels/5.4/out
```

Each successful build is placed in its own directory under artifacts/per-kernel/ and named using the exact kernel release reported by the kernel build system. The example paths and versions are illustrative; this repository does not contain prebuilt .ko files for every release.

A module can still fail to build if a kernel has API changes, vendor backports, missing exported symbols, or incompatible configuration. A successful compile is not proof that the module can be loaded on every device. Android GKI KMI and module-signing rules must also be met.
