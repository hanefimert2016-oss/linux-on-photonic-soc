// SPDX-License-Identifier: BSD-2-Clause
//
// dfb_laser.v
// ===========
//
// Behavioral model of a Distributed-Feedback (DFB) laser diode. A real DFB
// laser is a semiconductor laser with a Bragg-grating reflector embedded in
// the waveguide so that it lases at a single, well-defined wavelength
// (linewidth on the order of MHz).
//
// In this model a DFB laser is just a constant-intensity continuous-wave
// (CW) source. Its `lambda_id` is a logical wavelength index — i.e. the
// system has NUM_LAMBDAS distinct wavelengths, and each DFB laser is
// hard-wired to exactly one of them.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module dfb_laser #(
    parameter integer LAMBDA_ID = 0,
    parameter real    POWER     = `LASER_POWER
) (
    input  wire enable,
    output real intensity_out,
    output reg  [7:0] lambda_id_out
);

    initial begin
        lambda_id_out = LAMBDA_ID[7:0];
    end

    // The optical output is just the bias current turned on/off. In a real
    // device there is a small turn-on transient and threshold current; we
    // collapse all of that to "off when disabled, full power when enabled".
    assign intensity_out = enable ? POWER : 0.0;

endmodule
