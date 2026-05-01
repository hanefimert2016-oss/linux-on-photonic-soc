# Linux on a Photonic-Inspired RISC-V SoC

A reproducible, open-source RISC-V System-on-Chip that **boots BuildRoot Linux
under a software simulator on a stock Linux PC**, alongside a
**photon-pure optical link** (multiple DFB lasers, modulators, AWG demux,
photodetectors, TIA, CDR, BER counter) modelled in real-valued behavioural
Verilog.

The repo bundles three layers that fit together:

1. **Photon-pure optical link** ([`rtl/optical/`](rtl/optical/)) — 16 small
   Verilog modules that model the *light path itself*: an array of DFB
   lasers, MZ / microring modulators, a wavelength multiplexer, a silicon
   waveguide with attenuation and propagation delay, an AWG demux with
   inter-lambda crosstalk, photodetectors, transimpedance amplifiers, a
   bang-bang clock-and-data-recovery loop, and a bit-error-rate counter.
   Optical intensities flow through the chain as IEEE-754 reals; the only
   transistor-domain logic in the link is the digital data going in and the
   recovered data coming out.
2. **WDM data-fabric module** ([`rtl/wdm_fabric.v`](rtl/wdm_fabric.v)) —
   the synthesisable Wishbone-flavoured accelerator that an FPGA SoC can
   actually instantiate. Same architectural pattern (N parallel
   wavelengths, no contention) but with digital-only Verilog so it can ride
   alongside a regular CPU.
3. **Linux-capable RISC-V SoC** ([`sim/sim_linux.py`](sim/sim_linux.py)) —
   the full LiteX + VexRiscv-SMP + LiteDRAM SoC that boots BuildRoot Linux
   under Verilator on a stock Linux PC.

A single `make all` exercises all three: it builds the toolchain, runs the
photon-pure optical-link sim with BER measurement, runs the digital WDM
fabric testbench, and boots Linux.

> ⚠️  **What this repo is _not_:** Real silicon photonics needs custom
> fabrication, lasers, modulators, and detectors that no PC simulator can
> physically reproduce. The optical link in this repo is a **behavioural**
> model: optical intensities are real numbers, time is in clock cycles,
> and the DFB lasers / modulators / photodetectors are described by their
> *I/O contract*, not their device physics. What you can do is read the
> RTL, follow the chain end-to-end, watch real-valued waveforms in GTKWave,
> and confirm bit-perfect recovery through PRBS+BER tests.

---

## Architecture

### Photon-pure optical link (no transistor logic in the data path)

```
   +-------------+   +-----------+   +-----------+
   | DFB laser 0 |-->|           |-->|           |
   +-------------+   |           |   |           |
   +-------------+   |  modulator|   | wavelength|
   | DFB laser 1 |-->|    bank   |-->|    mux    |---+
   +-------------+   |           |   |           |   |
         ...         |  (8 MZs)  |   |  (8->1)   |   |
   +-------------+   |           |   |           |   |
   | DFB laser 7 |-->|           |-->|           |   |
   +-------------+   +-----------+   +-----------+   |
           ^               ^                         v
         tx_data[7:0]      |               +------------------+
                           |               |  optical waveg.  |
                           |               |  (loss + delay)  |
                           |               +------------------+
                           |                         |
                           |                         v
                           |               +------------------+
                           |               |   noise source   |
                           |               | (shot + thermal) |
                           |               +------------------+
                           |                         |
   +------------+    +------------+   +------------+ v
   | rx_data[7] |<---|    CDR     |<--| photodet.  |<--+
   |    ...     |    |  (3 stages,|   |  + TIA     |   | AWG
   | rx_data[0] |<---|  bang-bang)|<--|  bank      |<--+ demux
   +------------+    +------------+   +------------+   | (1->8)
                            ^                          |
                            +-- BER counter -----------+
```

* Light flows through the entire path as a real-valued intensity (0.0..1.0).
* No CPU / no Wishbone / no register file in the data path itself.
* `tx_data[k]` modulates the laser at wavelength λ_k via the MZ modulator.
* All N lambdas share a single physical waveguide between the mux and
  demux — that is the bandwidth-density advantage of WDM.

### Linux-capable digital SoC (with the WDM fabric as a peripheral)

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

### Inspect the photon-pure optical link

```bash
make sim-optical    # produces dump_optical.vcd, runs PRBS+BER test
make view-optical   # opens GTKWave with scripts/optical.gtkw preset
```

In GTKWave you will see, top-to-bottom for each lambda:

* a flat-line CW laser intensity (1.0 when enabled),
* a chopped-up modulator output (NRZ amplitude swing per bit),
* the bus intensity as light traverses the waveguide (with attenuation),
* a slightly-noisy version after the noise source,
* the recovered intensity at the AWG demux output port,
* the corresponding TIA voltage,
* and finally the recovered digital `rx_data[k]` line.

The testbench drives 8 independent PRBS-32 streams (one per lambda) and
asserts that **0 bit errors** occur over the run, with the CDR locked.

### Inspect the digital WDM waveform

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
├── Makefile                top-level build with sim-linux / sim-wdm / sim-optical
├── README.md               this file
├── rtl/
│   ├── wdm_fabric.v        digital WDM fabric (NUM_LAMBDAS lanes)
│   ├── wdm_scheduler.v     round-robin pattern generator for the fabric
│   └── optical/            photon-pure optical link (real-valued analog model)
│       ├── optical_constants.vh   parameters (powers, losses, threshold)
│       ├── dfb_laser.v            single DFB laser (CW, fixed wavelength)
│       ├── laser_array.v          N-element DFB laser bank
│       ├── mz_modulator.v         Mach-Zehnder data modulator
│       ├── ring_modulator.v       microring data modulator (alternative)
│       ├── modulator_bank.v       N-lane modulator bank
│       ├── wavelength_mux.v       N-to-1 wavelength MUX (combines lambdas)
│       ├── optical_waveguide.v    silicon waveguide (loss + delay)
│       ├── awg_demux.v            arrayed waveguide grating 1-to-N demux
│       ├── ring_drop_filter.v     microring drop filter (alternative demux)
│       ├── photodetector.v        Ge-on-Si photodetector + slicer
│       ├── tia_amplifier.v        transimpedance amplifier
│       ├── detector_bank.v        N-lane PD + TIA bank
│       ├── cdr_recovery.v         clock-and-data recovery
│       ├── ber_counter.v          bit-error-rate counter
│       ├── noise_source.v         shot/thermal noise injector
│       └── optical_link_top.v     top-level integration
├── tb/
│   ├── wdm_tb.v            Icarus testbench for the digital WDM fabric
│   └── optical_link_tb.v   Icarus testbench for the photon-pure optical link
├── sim/
│   └── sim_linux.py        LiteX/Migen SoC + Verilator simulation script
├── scripts/
│   ├── setup_litex.sh      installs LiteX into .venv + applies patches
│   ├── fetch_images.sh     downloads pre-built Linux/OpenSBI images
│   ├── run_sim.sh          launches the Verilator binary under unbuffer
│   ├── wdm.gtkw            GTKWave save file for the digital WDM testbench
│   └── optical.gtkw        GTKWave save file for the optical-link testbench
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
