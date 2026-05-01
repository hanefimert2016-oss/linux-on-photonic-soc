// SPDX-License-Identifier: BSD-2-Clause
//
// noise_source.v
// ==============
//
// Adds shot/thermal noise on top of a clean optical intensity. Shot noise
// scales as sqrt(P) and thermal noise is power-independent; both look
// statistically like band-limited Gaussian fluctuations. We emulate them
// with a simple uniform-distribution kick.
//
// AMPLITUDE is the maximum positive/negative excursion as a fraction of
// the laser nominal power. Set to 0.0 to disable noise entirely.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module noise_source #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS,
    parameter real    AMPLITUDE   = 0.02,
    parameter integer SEED        = 32'hC0FFEE
) (
    input  wire                       clk,
    input  wire [NUM_LAMBDAS*64-1:0]  intensity_in_pack,
    output reg  [NUM_LAMBDAS*64-1:0]  intensity_out_pack
);

    integer k;
    integer state;
    real    p_in, kick, p_out;

    initial state = SEED;

    always @(posedge clk) begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            // Cheap deterministic LCG; good enough for noise visuals.
            state = state * 1103515245 + 12345;
            kick  = AMPLITUDE * ($itor(state[15:0]) / 32768.0 - 1.0);
            p_in  = $bitstoreal(intensity_in_pack[k*64 +: 64]);
            p_out = p_in + kick;
            intensity_out_pack[k*64 +: 64] <= $realtobits(p_out);
        end
    end

endmodule
