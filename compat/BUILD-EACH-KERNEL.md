# Build a separate reverse_exe module for each kernel

Prepare a separate kernel source/output tree for every exact target kernel. Each must have its matching .config, generated headers, and Module.symvers when CONFIG_MODVERSIONS is enabled.

For Linux 5.10.x:

```bash
./scripts/build-module.sh /kernels/5.10.218/out
./scripts/build-module.sh /kernels/5.10.219/out
./scripts/build-module.sh /kernels/5.10.220/out
```

The resulting filenames are respectively:

- `reverse_exe-5.10.218.ko`
- `reverse_exe-5.10.219.ko`
- `reverse_exe-5.10.220.ko`

Build several exact trees in one run:

```bash
./scripts/build-many-kernels.sh /kernels/5.10.218/out /kernels/5.10.219/out /kernels/5.10.220/out
```

Each successful build is placed in its own directory under `artifacts/per-kernel/<full-kernel-release>-arm64/`. The filename uses the numeric major.minor.patch version; the directory and metadata preserve the full kernel release to prevent collisions between OEM builds.

The example paths and versions are illustrative; this repository does not contain prebuilt .ko files for every release. A module can fail to build if a kernel has API changes, vendor backports, missing exported symbols, or incompatible configuration. A successful compile is not proof that the module can be loaded on every device. Android GKI KMI and module-signing rules must also be met.
