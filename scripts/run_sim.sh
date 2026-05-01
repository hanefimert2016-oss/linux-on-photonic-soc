#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-2-Clause
#
# Run the pre-built Verilator SoC simulation (boot Linux).
#
# Build first with `make sim-linux`. This script just invokes the resulting
# Vsim binary through `unbuffer` so the libevent-driven serial2console module
# gets a real PTY to drive (it cannot speak to /dev/null).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VSIM="${REPO_ROOT}/build/sim/gateware/obj_dir/Vsim"

if [ ! -x "${VSIM}" ]; then
    echo "[run_sim] ${VSIM} not found, run 'make sim-linux' first." >&2
    exit 1
fi

cd "${REPO_ROOT}/build/sim/gateware"

if command -v unbuffer > /dev/null 2>&1; then
    exec unbuffer "${VSIM}" "$@"
else
    exec "${VSIM}" "$@"
fi
