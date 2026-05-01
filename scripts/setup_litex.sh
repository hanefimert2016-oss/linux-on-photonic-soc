#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2-Clause
#
# Set up the LiteX/Migen toolchain in a Python virtualenv and apply the
# small compatibility patches required to boot Linux on a current Ubuntu
# (newer picolibc layout, Verilator timescale strictness, etc.).
#
# Run from the repository root:
#   ./scripts/setup_litex.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LITEX_DIR="${LITEX_DIR:-${REPO_ROOT}/build/litex}"
VENV_DIR="${VENV_DIR:-${REPO_ROOT}/.venv}"

mkdir -p "${LITEX_DIR}"

# 1. Python venv -------------------------------------------------------------
if [ ! -x "${VENV_DIR}/bin/python3" ]; then
    echo "[setup_litex] Creating venv at ${VENV_DIR}"
    python3 -m venv "${VENV_DIR}"
fi
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
pip install --upgrade pip wheel setuptools meson ninja > /dev/null

# 2. litex_setup.py ----------------------------------------------------------
cd "${LITEX_DIR}"
if [ ! -f litex_setup.py ]; then
    wget -q https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
    chmod +x litex_setup.py
fi

# Init clones all the LiteX-* repos under ${LITEX_DIR}.
if [ ! -d litex ]; then
    echo "[setup_litex] Cloning LiteX ecosystem..."
    ./litex_setup.py --init
fi

# Install in editable mode into the venv.
echo "[setup_litex] Installing LiteX modules into venv..."
./litex_setup.py --install

# 3. Compatibility patches ---------------------------------------------------
PICOLIBC_DATA="${LITEX_DIR}/pythondata-software-picolibc/pythondata_software_picolibc/data"
if [ -d "${PICOLIBC_DATA}/libc" ] && [ ! -e "${PICOLIBC_DATA}/newlib/libc/include" ]; then
    echo "[setup_litex] Patching picolibc layout (newlib -> libc symlinks)"
    mkdir -p "${PICOLIBC_DATA}/newlib/libc"
    ln -sfn ../../libc/include "${PICOLIBC_DATA}/newlib/libc/include"
    ln -sfn ../../libc/stdio   "${PICOLIBC_DATA}/newlib/libc/tinystdio"
fi

LIBC_MK="${LITEX_DIR}/litex/litex/soc/software/libc/Makefile"
if [ -f "${LIBC_MK}" ] && grep -q '^[[:space:]]*cp newlib/libc.a __libc.a$' "${LIBC_MK}"; then
    echo "[setup_litex] Patching libc Makefile to fall back to libc.a"
    sed -i 's|^\tcp newlib/libc.a __libc.a$|\tif [ -f newlib/libc.a ]; then cp newlib/libc.a __libc.a; else cp libc.a __libc.a; fi|' "${LIBC_MK}"
fi

LITEDRAM_UTILS="${LITEX_DIR}/litex/litex/soc/software/liblitedram/utils.c"
if [ -f "${LITEDRAM_UTILS}" ] && ! grep -q '<inttypes.h>' "${LITEDRAM_UTILS}"; then
    echo "[setup_litex] Adding inttypes.h to liblitedram/utils.c"
    sed -i '0,/#include <stdio.h>/s||#include <stdio.h>\n#include <inttypes.h>|' "${LITEDRAM_UTILS}"
fi

SIM_MK="${LITEX_DIR}/litex/litex/build/sim/core/Makefile"
if [ -f "${SIM_MK}" ] && ! grep -q 'Wno-TIMESCALEMOD' "${SIM_MK}"; then
    echo "[setup_litex] Adding -Wno-TIMESCALEMOD to Verilator flags"
    sed -i 's|-Wno-CASEINCOMPLETE \\|-Wno-CASEINCOMPLETE \\\n\t\t-Wno-TIMESCALEMOD \\|' "${SIM_MK}"
fi

echo "[setup_litex] Done."
