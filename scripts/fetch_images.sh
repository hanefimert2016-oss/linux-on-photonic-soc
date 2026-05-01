#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2-Clause
#
# Download the pre-built BuildRoot Linux + OpenSBI images for the
# VexRiscv-SMP simulator. These are published by the upstream
# linux-on-litex-vexriscv project and contain:
#
#   Image         - Linux kernel
#   opensbi.bin   - RISC-V OpenSBI firmware (M-mode)
#   rv32.dtb      - Device tree for the simulated SoC
#   rootfs.cpio   - BuildRoot rootfs
#   boot.json     - LiteX boot manifest

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGES_DIR="${REPO_ROOT}/images"
URL="https://github.com/litex-hub/linux-on-litex-vexriscv/files/8331338/linux_2022_03_23.zip"
ZIP="${IMAGES_DIR}/linux_2022_03_23.zip"

mkdir -p "${IMAGES_DIR}"

if [ -f "${IMAGES_DIR}/Image" ] \
   && [ -f "${IMAGES_DIR}/opensbi.bin" ] \
   && [ -f "${IMAGES_DIR}/rv32.dtb" ] \
   && [ -f "${IMAGES_DIR}/rootfs.cpio" ]; then
    echo "[fetch_images] Linux/OpenSBI images already present in ${IMAGES_DIR}, skipping."
    exit 0
fi

echo "[fetch_images] Downloading ${URL}"
if command -v wget > /dev/null 2>&1; then
    wget -q "${URL}" -O "${ZIP}"
elif command -v curl > /dev/null 2>&1; then
    curl -fsSL "${URL}" -o "${ZIP}"
else
    echo "[fetch_images] Need wget or curl on PATH." >&2
    exit 1
fi

echo "[fetch_images] Extracting into ${IMAGES_DIR}"
unzip -o -q "${ZIP}" -d "${IMAGES_DIR}"
rm -f "${ZIP}"

# LiteX expects this manifest naming for ROM-resident boot.
if [ ! -f "${IMAGES_DIR}/boot_ram0.json" ]; then
    cat > "${IMAGES_DIR}/boot_ram0.json" <<'JSON'
{
        "Image"       : "0x40000000",
        "rv32.dtb"    : "0x40ef0000",
        "rootfs.cpio" : "0x41000000",
        "opensbi.bin" : "0x40f00000"
}
JSON
fi

echo "[fetch_images] Done."
ls -la "${IMAGES_DIR}"
