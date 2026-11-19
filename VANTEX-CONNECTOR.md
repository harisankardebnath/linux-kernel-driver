# VANTEX connector integration (safe test interface)

The uploaded `driver.h` contains process-PID/address read/write operations, module-base lookup, hidden-process operations, automatic device-node discovery, and alternate driver/prctl hooks. Those capabilities are intentionally not integrated into VANTEX.

VANTEX exposes only its explicit device node, `/dev/reverse_exe`, and a private bounded 4 KiB test buffer. An application you own can open that exact node and perform normal file-descriptor read/write calls on the test buffer. It can also use the driver's documented clear and size ioctls.

## Connector choice in the VANTEX TUI

1. **No connector** — manage the kernel module only.
2. **Owned test application** — verify that `/dev/reverse_exe` exists and is a character device, then open that exact path.
3. **Disconnect** — close the application file descriptor; this does not unload the kernel module.

The connector must not accept a PID, process name, arbitrary address, game package, module name, or hidden device-node search. It must not expose arbitrary process memory or anti-cheat controls.

## Device checks

Before opening the node, require explicit user selection, verify ARM64 and the running kernel, check that the node is the expected character device, and report ordinary permission errors. Never create a guessed device node or scan `/dev` for an unknown driver.

## CI scope

The GitHub workflow builds against upstream Linux stable defconfigs for ARM64. These are generic build artifacts, not guaranteed Android vendor-kernel binaries. For a real Android device, build against that device's exact source, config, generated headers, symbol versions, toolchain, KMI and signing policy.
