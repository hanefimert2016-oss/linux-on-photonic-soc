# SPDX-License-Identifier: BSD-2-Clause
#
# Top-level Makefile for the photonic-inspired Linux SoC.
#
# Targets:
#   make all          - install LiteX, fetch images, run all simulations
#   make setup        - install LiteX/Migen toolchain into .venv
#   make images       - fetch pre-built BuildRoot Linux + OpenSBI images
#   make sim-linux    - build the Verilator SoC and boot Linux
#   make sim-wdm      - run the Icarus WDM data-fabric testbench
#   make view-wdm     - open dump.vcd in GTKWave with the WDM save file
#   make sim-optical  - run the photon-pure optical link testbench
#                       (real-valued analog: lasers, modulators, AWG demux,
#                        photodetectors, TIA, CDR, BER counter)
#   make view-optical - open dump_optical.vcd in GTKWave
#   make clean        - remove build artefacts
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

# Photon-pure optical link testbench
OPT_RTL_DIR    := rtl/optical
OPT_RTL_SRCS   := \
    $(OPT_RTL_DIR)/dfb_laser.v \
    $(OPT_RTL_DIR)/laser_array.v \
    $(OPT_RTL_DIR)/mz_modulator.v \
    $(OPT_RTL_DIR)/ring_modulator.v \
    $(OPT_RTL_DIR)/modulator_bank.v \
    $(OPT_RTL_DIR)/wavelength_mux.v \
    $(OPT_RTL_DIR)/optical_waveguide.v \
    $(OPT_RTL_DIR)/awg_demux.v \
    $(OPT_RTL_DIR)/ring_drop_filter.v \
    $(OPT_RTL_DIR)/photodetector.v \
    $(OPT_RTL_DIR)/tia_amplifier.v \
    $(OPT_RTL_DIR)/detector_bank.v \
    $(OPT_RTL_DIR)/cdr_recovery.v \
    $(OPT_RTL_DIR)/ber_counter.v \
    $(OPT_RTL_DIR)/noise_source.v \
    $(OPT_RTL_DIR)/optical_link_top.v
OPT_TB_SRC     := tb/optical_link_tb.v
OPT_VVP        := build/optical.vvp
OPT_VCD        := dump_optical.vcd
OPT_GTKW       := scripts/optical.gtkw

.PHONY: all setup images sim-linux sim-wdm view-wdm sim-optical view-optical clean help

help:
	@echo "Photonic-inspired Linux SoC"
	@echo ""
	@echo "Targets:"
	@echo "  make setup        - install LiteX/Migen toolchain into .venv (~5-10 min)"
	@echo "  make images       - fetch pre-built BuildRoot Linux + OpenSBI images"
	@echo "  make sim-linux    - build Verilator SoC and boot Linux (~10 min first build)"
	@echo "  make sim-wdm      - run Icarus WDM data-fabric testbench (~5 sec)"
	@echo "  make view-wdm     - open the WDM waveform in GTKWave"
	@echo "  make sim-optical  - run photon-pure optical link sim (~5 sec)"
	@echo "  make view-optical - open the optical-link waveform in GTKWave"
	@echo "  make all          - run setup, images, sim-wdm, sim-optical, sim-linux"
	@echo "  make clean        - remove build artefacts"

all: setup images sim-wdm sim-optical sim-linux

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

# ---- Photon-pure optical link Icarus testbench ---------------------------

$(OPT_VVP): $(OPT_RTL_SRCS) $(OPT_TB_SRC) | build
	iverilog -g2012 -I $(OPT_RTL_DIR) -o $@ $(OPT_RTL_SRCS) $(OPT_TB_SRC)

sim-optical: $(OPT_VVP)
	@echo ">>> Running photon-pure optical link testbench (8 DFB lasers)..."
	@vvp $(OPT_VVP)
	@ls -la $(OPT_VCD)

view-optical: $(OPT_VCD)
	gtkwave $(OPT_VCD) $(OPT_GTKW)

clean:
	rm -rf build $(WDM_VCD) $(WDM_VVP) $(OPT_VCD) $(OPT_VVP)
