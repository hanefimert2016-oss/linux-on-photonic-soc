// SPDX-License-Identifier: BSD-2-Clause
//
// wavelength_mux.v
// ================
//
// Wavelength multiplexer (MUX). Combines NUM_LAMBDAS wavelength channels
// onto a single output waveguide.
//
// In a real silicon-photonic IC this is implemented as either:
//
//   - an Arrayed Waveguide Grating (AWG) used in reverse, or
//   - a cascade of microring add filters tuned to each λ.
//
// The behavioral model exposes:
//
//   - bus_intensity_pack[k]   : intensity carried at lambda k on the bus
//   - bus_total               : aggregate optical power on the waveguide
//
// Conservation: total_out = sum(intensity_in[k]) * MUX_LOSS.
// MUX_LOSS captures insertion loss of the combiner (typically 1-3 dB).

`timescale 1ns / 1ps
`include "optical_constants.vh"

module wavelength_mux #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire [NUM_LAMBDAS*64-1:0] intensity_in_pack,
    output reg  [NUM_LAMBDAS*64-1:0] bus_intensity_pack,
    output reg  [63:0]               bus_total_pack
);

    integer k;
    real    p_in, p_out, sum_tmp;

    always @* begin
        sum_tmp = 0.0;
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            p_in  = $bitstoreal(intensity_in_pack[k*64 +: 64]);
            p_out = p_in * `MUX_LOSS;
            bus_intensity_pack[k*64 +: 64] = $realtobits(p_out);
            sum_tmp = sum_tmp + p_out;
        end
        bus_total_pack = $realtobits(sum_tmp);
    end

endmodule
