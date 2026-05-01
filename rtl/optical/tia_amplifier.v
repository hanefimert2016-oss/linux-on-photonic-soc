// SPDX-License-Identifier: BSD-2-Clause
//
// tia_amplifier.v
// ===============
//
// Transimpedance Amplifier (TIA). The TIA sits immediately after the
// photodetector on a real photonic receiver and converts the photo-current
// (μA range) into a voltage that downstream circuitry can sample. The
// TIA's gain (in V/A) and bandwidth set the link's eye-diagram shape.
//
// Behavioral model: we keep the analog signal as a `real` "voltage" and
// just multiply by a programmable gain factor.

`timescale 1ns / 1ps

module tia_amplifier #(
    parameter real GAIN = 4.0
) (
    input  real photo_current,
    output real voltage_out
);

    assign voltage_out = photo_current * GAIN;

endmodule
