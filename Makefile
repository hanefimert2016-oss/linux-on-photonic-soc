# SPDX-License-Identifier: BSD-2-Clause
#
# Top-level Makefile for the photonic-inspired Linux SoC.
#
# Targets:
#   make all         - install LiteX, fetch images, build SoC, run WDM testbench
#   make setup       - install LiteX/Migen toolchain into .venv
#   make images      - fetch pre-built BuildRoot Linux + OpenSBI images
#   make sim-linux   - build the Verilator SoC and boot Linux
#   make sim-wdm     - run the Icarus WDM photonic-fabric testbench (writes dump.vcd)
#   make view-wdm    - open dump.vcd in GTKWave with the prepared save file
#   make clean       - remove build artefacts
#
# A single `make all` from a fresh clone takes ~15 minutes the first time
# (LiteX clone + Verilator compile) and ~30 seconds for the WDM testbench.

REPO_ROOT      := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VENV           := $(REPO_ROOT)/.venv
PY             := $(VENV)/bin/python3
LITEX_DIR      := $(REPO_ROOT)/build/litex
BUILD_DIR      := $(REPO_ROOT)/build/sim
IMAGES_DIR     := $(REPO_ROOT)/images

# WDM testbench
WDM_RTL_SRCS   := rtl/wdm_fabric.v rtl/wdm_scheduler.v
WDM_TB_SRC     := tb/wdm_tb.v
WDM_VVP        := build/wdm.vvp
WDM_VCD        := dump.vcd
WDM_GTKW       := scripts/wdm.gtkw

.PHONY: all setup images sim-linux sim-wdm view-wdm clean help

help:
	@echo "Photonic-inspired Linux SoC"
	@echo ""
	@echo "Targets:"
	@echo "  make setup       - install LiteX/Migen toolchain into .venv (~5-10 min)"
	@echo "  make images      - fetch pre-built BuildRoot Linux + OpenSBI images"
	@echo "  make sim-linux   - build Verilator SoC and boot Linux (~10 min first build)"
	@echo "  make sim-wdm     - run Icarus WDM photonic-fabric testbench (~5 sec)"
	@echo "  make view-wdm    - open the WDM waveform in GTKWave"
	@echo "  make all         - run setup, images, sim-wdm, sim-linux end-to-end"
	@echo "  make clean       - remove build artefacts"

all: setup images sim-wdm sim-linux

setup:
	@echo ">>> Installing LiteX toolchain..."
	@LITEX_DIR=$(LITEX_DIR) VENV_DIR=$(VENV) ./scripts/setup_litex.sh

images:
	@./scripts/fetch_images.sh

sim-linux: images
	@if [ ! -x $(VENV)/bin/python3 ]; then \
	    echo "Run 'make setup' first." >&2; exit 1; \
	fi
	@echo ">>> Building Verilator SoC + booting Linux..."
	@cd $(REPO_ROOT) && \
	    PYTHONPATH=$(LITEX_DIR) \
	    LITEX_ROOT=$(LITEX_DIR) \
	    $(PY) sim/sim_linux.py \
	        --build-dir  $(BUILD_DIR) \
	        --images-dir $(IMAGES_DIR) \
	        --threads 2

# ---- WDM photonic-fabric Icarus testbench --------------------------------

build:
	@mkdir -p build

$(WDM_VVP): $(WDM_RTL_SRCS) $(WDM_TB_SRC) | build
	iverilog -g2012 -o $@ $(WDM_RTL_SRCS) $(WDM_TB_SRC)

sim-wdm: $(WDM_VVP)
	@echo ">>> Running WDM photonic-fabric testbench..."
	@vvp $(WDM_VVP)
	@ls -la $(WDM_VCD)

view-wdm: $(WDM_VCD)
	gtkwave $(WDM_VCD) $(WDM_GTKW)

clean:
	rm -rf build $(WDM_VCD) $(WDM_VVP)
