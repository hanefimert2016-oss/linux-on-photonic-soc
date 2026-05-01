# Linux on a Photonic-Inspired RISC-V SoC

A reproducible, open-source RISC-V System-on-Chip that **boots BuildRoot Linux
under a software simulator on a stock Linux PC** and ships with a
**photonic-inspired wavelength-division-multiplexed (WDM) data fabric** as a
behavioral RTL model.

The intent of this repo is to bridge two ideas:

1. *"Light-based architectures get GHz throughput by sending data on many
   independent optical wavelengths in parallel through the same waveguide."* —
   We model that **architectural** property in synthesizable Verilog: many
   independent channels operating in parallel on a shared bus, scaling
   throughput linearly with the number of channels.
2. *"Can we still actually run real software on it?"* — Yes. The same
   repository builds a full Linux-capable RISC-V SoC (VexRiscv-SMP + LiteX +
   LiteDRAM) and boots BuildRoot Linux under Verilator, all from a single
   `make all`.

> ⚠️  **What this repo is _not_:** It is not a real photonic chip and it does
> not run at GHz wall-clock speed. Real silicon photonics needs custom
> fabrication, lasers, modulators, and detectors that no PC simulator can
> reproduce. What we *can* model in HDL — and what we do model — is the
> *architectural pattern* that makes photonic interconnects fast: massive
> parallelism on independent wavelength channels.

---

## Architecture

```
                +------------------------------------------------+
                |                  PhotonicSoCLinux              |
                |                                                |
                |   +--------------+    +----------------+       |
                |   | VexRiscv-SMP |<-->| LiteDRAM model |       |
                |   |  RV32IMA+MMU |    |   (64 MiB)     |       |
                |   +--------------+    +----------------+       |
                |          |                    ^                |
                |          v                    |                |
                |   +-----------------------------------+        |
                |   |        LiteX wishbone bus         |        |
                |   +-----------------------------------+        |
                |     |        |          |         |            |
                |  +----+   +-----+   +-------+  +----------+    |
                |  |ROM |   |UART |   | PLIC  |  |  WDM     |    |
                |  | 64K|   | sim |   |+CLINT |  |  fabric  |    |
                |  +----+   +-----+   +-------+  +----------+    |
                |                                  ^             |
                |                                  | 8 lambdas   |
                |                                  v             |
                |                          (photonic-inspired    |
                |                           parallel data link)  |
                +------------------------------------------------+
                                |
                          serial2console
                                v
                        host terminal
                       (root@buildroot)
```

* **CPU:** `VexRiscv-SMP` in `linux` variant — 32-bit RISC-V (RV32IMA + MMU,
  Linux-capable). Single-hart in this configuration; `--cpu-count=2` works
  too if you want SMP.
* **Bootloader chain:** LiteX BIOS in integrated ROM → OpenSBI in main RAM
  (`opensbi.bin`) → Linux kernel (`Image`) → BuildRoot rootfs (`rootfs.cpio`).
* **Memory:** Behavioral SDRAM model (`SDRAMPHYModel`, 64 MiB), pre-initialized
  from `boot_ram0.json` so the simulation jumps straight into OpenSBI/Linux
  without needing to load the kernel over a UART link.
* **Console:** UART exposed to the host via the LiteX `serial2console` sim
  module. Run through `unbuffer` to give libevent a real PTY.
* **WDM photonic-inspired fabric** (this repo's contribution): 8 independent
  32-bit wavelength channels (configurable), instantiable next to the SoC for
  high-bandwidth peripherals. Aggregate bandwidth is
  `NUM_LAMBDAS × DATA_WIDTH × f_clk`.

### Why is the WDM fabric "photonic-inspired"?

A real silicon-photonic WDM link sends multiple laser wavelengths
(λ₀, λ₁, …, λ₇) down the same waveguide simultaneously. Each wavelength
carries its own bit stream, and at the receiver an arrayed waveguide grating
demultiplexes them back into independent electrical lanes. The aggregate
throughput is N × per-lane rate.

The HDL in [`rtl/wdm_fabric.v`](rtl/wdm_fabric.v) captures this
*architectural* pattern:

* Each "wavelength" λₖ is a logically independent bus of `DATA_WIDTH` bits.
* All N channels transmit simultaneously on every clock edge — there is no
  arbitration or contention between them.
* Total useful bandwidth grows linearly with `NUM_LAMBDAS`.

That is purely architecture-level; the photonic *physics* (modulators, ring
filters, detectors) are out of scope. But the resulting RTL is FPGA-portable
and can be synthesised on a real Xilinx/Lattice/Gowin FPGA, which is the
typical use of this style of fabric in an open hardware design.

### Throughput numbers

| Clock target  | Channels | Bits / channel | Aggregate |
|---------------|---------:|---------------:|----------:|
| 100 MHz (FPGA) | 8 | 32 | 25.6 Gb/s |
| 250 MHz (fast FPGA) | 8 | 32 | 64 Gb/s |
| 5 GHz (real photonic, hypothetical) | 8 | 32 | 1.28 Tb/s |

The 100 MHz number is what you would actually see on an Artix-7-class FPGA
running this fabric. The 5 GHz number is what a real silicon-photonic link
can sustain — and it is what motivates the WDM architectural choice in the
first place.

---

## Quick start

Tested on Ubuntu 22.04 LTS with Python 3.10 / 3.12.

### One-shot build

```bash
sudo apt install -y build-essential verilator iverilog gtkwave \
    gcc-riscv64-unknown-elf device-tree-compiler libevent-dev libjson-c-dev \
    expect unzip wget python3 python3-venv

git clone https://github.com/<you>/linux-on-photonic-soc.git
cd linux-on-photonic-soc

make all
```

`make all` runs, in order:

1. `make setup` &mdash; clones LiteX/Migen and installs them into `.venv`,
   applying compatibility patches for newer picolibc and Verilator.
2. `make images` &mdash; downloads the pre-built
   BuildRoot Linux + OpenSBI images.
3. `make sim-wdm` &mdash; compiles `rtl/wdm_*.v` + `tb/wdm_tb.v` with Icarus,
   produces `dump.vcd`.
4. `make sim-linux` &mdash; generates the SoC, runs Verilator, boots Linux
   to a `buildroot login:` prompt.

### Inspect the photonic WDM waveform

```bash
make sim-wdm    # produces dump.vcd
make view-wdm   # opens GTKWave with scripts/wdm.gtkw preset
```

Eight wavelength buses (λ₀…λ₇) advance together every clock cycle — this is
the visible WDM behaviour.

### Boot Linux

```bash
make sim-linux
```

Expected output (abbreviated):

```
        __   _ __      _  __
       / /  (_) /____ | |/_/
      / /__/ / __/ -_)>  <
     /____/_/\__/\__/_/|_|
   Build your hardware, easily!

 BIOS built on ...
--=============== SoC ==================--
CPU:            VexRiscv SMP-LINUX @ 100MHz
ROM:            64.0KiB
SDRAM:          64.0MiB 32-bit @ 100MT/s

--========== Initialization ============--
Initializing SDRAM @0x40000000...
Switching SDRAM to hardware control.

--============== Boot ==================--
Booting from serial...
Timeout
Executing booted program at 0x40f00000

--============= Liftoff! ===============--

OpenSBI v0.8-1-gecf7701
[    0.000000] Linux version 5.14.0 ...
...
buildroot login: root
#
```

---

## Repository layout

```
.
├── Makefile                top-level build with sim-linux / sim-wdm targets
├── README.md               this file
├── rtl/
│   ├── wdm_fabric.v        photonic-inspired WDM fabric (NUM_LAMBDAS lanes)
│   └── wdm_scheduler.v     round-robin pattern generator that drives the fabric
├── tb/
│   └── wdm_tb.v            Icarus testbench, dumps dump.vcd
├── sim/
│   └── sim_linux.py        LiteX/Migen SoC + Verilator simulation script
├── scripts/
│   ├── setup_litex.sh      installs LiteX into .venv + applies patches
│   ├── fetch_images.sh     downloads pre-built Linux/OpenSBI images
│   ├── run_sim.sh          launches the Verilator binary under unbuffer
│   └── wdm.gtkw            GTKWave save file with all lambdas pre-loaded
└── docs/
    └── ARCHITECTURE.md     longer architecture / FPGA-portability notes
```

---

## Performance & realism notes

* **Verilator boot speed.** Booting the kernel to userspace takes
  ~5–10 minutes of wall-clock time on a 2-vCPU laptop. The simulator runs
  Verilator at ~10–50 kHz of *simulated* clock; Linux boot needs roughly
  200–400 M cycles. Disabling VCD trace (`platform.trace.eq(0)`) is **the**
  difference between a 1-hour boot and a 5-minute boot, so it is off by
  default.
* **Photonic GHz speeds are not reproducible in simulation.** The HDL is
  clocked at simulator-speed, not silicon-speed. The throughput table above
  is what the same RTL would deliver on real hardware (FPGA today, ASIC or
  silicon-photonic ASIC tomorrow). On the simulator the WDM fabric still
  *exposes* the architecture — that is what `dump.vcd` proves.
* **Why VexRiscv-SMP and not bigger cores?** VexRiscv-SMP is the only
  open-source 32-bit Linux-capable RISC-V core whose pre-built BSP fits in
  reasonable simulation memory and boots in single-digit minutes. Cores
  like Rocket or BOOM are also open source but compile slower under
  Verilator and need more host RAM.

---

## Acknowledgements

* [LiteX](https://github.com/enjoy-digital/litex) — Florent Kermarrec /
  Enjoy-Digital. The SoC is generated by LiteX, and the simulation
  scaffolding (BIOS, SDRAM model, sim-UART, build infrastructure) is from
  LiteX.
* [linux-on-litex-vexriscv](https://github.com/litex-hub/linux-on-litex-vexriscv)
  — provides the pre-built BuildRoot Linux + OpenSBI images and the original
  reference `sim.py` that `sim/sim_linux.py` is derived from.
* [VexRiscv / VexRiscv-SMP](https://github.com/SpinalHDL/VexRiscv) —
  Charles Papon. The Linux-capable 32-bit RISC-V CPU.
* [Verilator](https://verilator.org), [Icarus Verilog](https://github.com/steveicarus/iverilog),
  [GTKWave](https://gtkwave.sourceforge.net) — the open-source simulators
  this repository targets.

## License

BSD 2-Clause, matching the upstream LiteX / linux-on-litex-vexriscv ecosystem.
See [LICENSE](LICENSE).
