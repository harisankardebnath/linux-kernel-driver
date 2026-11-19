#!/system/bin/sh
# VANTEX Driver Manager v1.0
# Generic manager for a legitimate, user-supplied ARM64 Linux kernel module.
# This script does not implement process-memory access or anti-cheat bypass.

set -u

APP="VANTEX DRIVER"
VERSION="1.0"
MODULE_FILE="${1:-./vantex.ko}"
MODULE_NAME=""

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
cyan() { printf '\033[36m%s\033[0m\n' "$*"; }

pause() {
    printf '\nPress Enter to continue...'
    read -r _
}

root_check() {
    if [ "$(id -u 2>/dev/null || echo 1)" != "0" ]; then
        red "Root access is required. Run: su -c sh $0"
        return 1
    fi
    return 0
}

normalise_name() {
    base=$(basename "$MODULE_FILE")
    base=${base%.ko}
    MODULE_NAME=$(printf '%s' "$base" | tr '-' '_')
}

is_loaded() {
    [ -d "/sys/module/$MODULE_NAME" ] || grep -qE "^$MODULE_NAME " /proc/modules 2>/dev/null
}

show_header() {
    clear 2>/dev/null || true
    cyan "=========================================="
    cyan "          VANTEX DRIVER v$VERSION"
    cyan "=========================================="
    printf 'Kernel : %s\n' "$(uname -r)"
    printf 'Arch   : %s\n' "$(uname -m)"
    printf 'Module : %s\n' "$MODULE_NAME"
    printf 'File   : %s\n' "$MODULE_FILE"
    if is_loaded; then green "Status : LOADED"; else yellow "Status : NOT LOADED"; fi
    cyan "------------------------------------------"
}

show_logs() {
    if command -v dmesg >/dev/null 2>&1; then
        dmesg 2>/dev/null | tail -n 60
    else
        yellow "dmesg is unavailable."
    fi
}

check_module() {
    [ -f "$MODULE_FILE" ] || { red "Module file not found: $MODULE_FILE"; return 1; }
    case "$(uname -m)" in
        aarch64|arm64) ;;
        *) red "This build manager expects an ARM64 device."; return 1 ;;
    esac
    if command -v modinfo >/dev/null 2>&1; then
        vermagic=$(modinfo -F vermagic "$MODULE_FILE" 2>/dev/null || true)
        if [ -n "$vermagic" ]; then
            module_kernel=$(printf '%s' "$vermagic" | awk '{print $1}')
            running_kernel=$(uname -r)
            if [ "$module_kernel" != "$running_kernel" ]; then
                red "Kernel mismatch."
                printf 'Module vermagic: %s\nRunning kernel : %s\n' "$module_kernel" "$running_kernel"
                return 1
            fi
        else
            yellow "Could not read module vermagic; continuing with kernel's own loader checks."
        fi
    else
        yellow "modinfo unavailable; the kernel will validate module compatibility."
    fi
    return 0
}

load_module() {
    root_check || return
    if is_loaded; then
        green "Already loaded — skipping duplicate load."
        return
    fi
    check_module || return
    if ! command -v insmod >/dev/null 2>&1; then red "insmod not found."; return; fi
    printf 'Loading %s...\n' "$MODULE_FILE"
    if insmod "$MODULE_FILE"; then
        sleep 1
        if is_loaded; then green "Load successful and module presence verified."
        else red "insmod returned success, but module is not present in /sys/module."; show_logs
        fi
    else
        red "Module load failed. No automatic reboot will be performed."
        show_logs
        printf '\nReboot now? This may interrupt your device. Type REBOOT to confirm: '
        read -r answer
        if [ "$answer" = "REBOOT" ]; then
            if command -v reboot >/dev/null 2>&1; then reboot
            else red "reboot command not found."
            fi
        else
            yellow "Reboot cancelled. Review the kernel log and module compatibility."
        fi
    fi
}

unload_module() {
    root_check || return
    if ! is_loaded; then yellow "Module is not loaded."; return; fi
    if ! command -v rmmod >/dev/null 2>&1; then red "rmmod not found."; return; fi
    printf 'Unload %s? Type UNLOAD to confirm: ' "$MODULE_NAME"
    read -r answer
    [ "$answer" = "UNLOAD" ] || { yellow "Unload cancelled."; return; }
    if rmmod "$MODULE_NAME"; then
        if is_loaded; then red "Unload command returned, but module is still present."
        else green "Module unloaded successfully."
        fi
    else
        red "Unload failed — the module may be in use or marked non-unloadable."
        show_logs
    fi
}

reload_module() {
    unload_module
    if ! is_loaded; then load_module; fi
}

driver_info() {
    printf 'VANTEX Driver Manager: %s\n' "$VERSION"
    printf 'Device architecture : %s\n' "$(uname -m)"
    printf 'Kernel release      : %s\n' "$(uname -r)"
    printf 'Module path         : %s\n' "$MODULE_FILE"
    printf 'Module name         : %s\n' "$MODULE_NAME"
    if command -v modinfo >/dev/null 2>&1 && [ -f "$MODULE_FILE" ]; then
        modinfo "$MODULE_FILE" 2>/dev/null || true
    fi
}

normalise_name
while :; do
    show_header
    printf '  1) Load module\n'
    printf '  2) Check loaded status\n'
    printf '  3) Reload module\n'
    printf '  4) Unload module\n'
    printf '  5) Driver / build information\n'
    printf '  6) View recent kernel logs\n'
    printf '  7) Exit\n'
    printf '\nSelect: '
    read -r choice
    case "$choice" in
        1) load_module; pause ;;
        2) if is_loaded; then green "VANTEX module is loaded."; else yellow "VANTEX module is not loaded."; fi; pause ;;
        3) reload_module; pause ;;
        4) unload_module; pause ;;
        5) driver_info; pause ;;
        6) show_logs; pause ;;
        7) cyan "VANTEX manager closed. Driver state unchanged."; exit 0 ;;
        *) red "Invalid option."; pause ;;
    esac
done
