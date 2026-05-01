// SPDX-License-Identifier: BSD-2-Clause
//
// mz_modulator.v
// ==============
//
// Behavioral model of a Mach-Zehnder Interferometer (MZI) electro-optic
// modulator. A real MZ modulator splits the incoming CW light into two
// arms, applies a voltage-controlled phase shift to one of them, and
// recombines them so that constructive interference passes light through
// (= "1") and destructive interference blocks it (= "0").
//
// We collapse the optics down to its observable behaviour:
//
//     out_intensity = in_intensity *  data           if data = 1
//                   = in_intensity *  EXTINCTION    if data = 0
//
// where EXTINCTION (typically 1-5%) is the residual leakage of a real
// modulator: even at the "off" bias point, a small amount of light passes
// through. This is what limits how cleanly a photodetector can recover the
// bit downstream.
//
// One MZ modulator handles ONE wavelength. To modulate N wavelengths we
// instantiate N of them — see modulator_bank.v.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module mz_modulator (
    input  wire data_in,
    input  real intensity_in,
    output real intensity_out
);

    assign intensity_out = data_in ? intensity_in
                                   : intensity_in * `MOD_ER;

endmodule
