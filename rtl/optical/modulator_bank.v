// SPDX-License-Identifier: BSD-2-Clause
//
// modulator_bank.v
// ================
//
// Bank of N MZ modulators. Each lambda_k is driven by its own modulator and
// its own data bit, in parallel. This is the photonic equivalent of an
// 8-lane parallel transmitter — but unlike electrical buses, all lanes
// operate on the same waveguide downstream because they sit at different
// wavelengths.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module modulator_bank #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire [NUM_LAMBDAS-1:0]    tx_data,
    input  wire [NUM_LAMBDAS*64-1:0] intensity_in_pack,
    output reg  [NUM_LAMBDAS*64-1:0] intensity_out_pack
);

    integer k;
    real    p_in, p_out;

    always @* begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            p_in  = $bitstoreal(intensity_in_pack[k*64 +: 64]);
            p_out = tx_data[k] ? p_in : p_in * `MOD_ER;
            intensity_out_pack[k*64 +: 64] = $realtobits(p_out);
        end
    end

endmodule
