// SPDX-License-Identifier: BSD-2-Clause
//
// optical_constants.vh
// ====================
//
// Behavioral parameters used across the photonic-link RTL. Everything is
// dimensionless / normalized:
//
//   * intensity    : 0.0 .. 1.0 (1.0 = nominal laser output power)
//   * wavelength   : index in [0, NUM_LAMBDAS-1], NOT a physical nanometer
//   * loss / gain  : multiplicative real factor (0.0 .. 1.0+)
//
// These are NOT physical units. The module set models the *architectural*
// behaviour of an N-laser silicon-photonic WDM link. For a real-physics
// model you would need a dedicated photonic SPICE-class simulator.
//
// Real-valued analog signals are passed between modules as packed
// bit-vectors using $realtobits / $bitstoreal so they cross module ports
// reliably under all simulators (iverilog 2012, Verilator, etc.).

`ifndef OPTICAL_CONSTANTS_VH
`define OPTICAL_CONSTANTS_VH

`define NUM_LAMBDAS    8       // wavelength channels (= number of DFB lasers)
`define DATA_WIDTH     1       // bits/symbol (NRZ on each lambda)
`define LASER_POWER    1.0     // nominal CW power per laser (intensity)
`define WG_LOSS        0.95    // waveguide power-transmission per hop
`define MOD_ER         0.05    // modulator extinction ratio: bit-0 leakage
`define PD_THRESHOLD   0.40    // photodetector decision threshold (intensity)
`define MUX_LOSS       0.92    // wavelength mux insertion loss
`define DEMUX_LOSS     0.88    // AWG demux insertion loss
`define CROSSTALK      0.005   // adjacent-lambda leakage in demux

// Packed-real conventions for cross-module ports:
//   bus[i*64 +: 64] holds a single real number in IEEE-754 form.
`define REAL_BITS      64

`endif // OPTICAL_CONSTANTS_VH
