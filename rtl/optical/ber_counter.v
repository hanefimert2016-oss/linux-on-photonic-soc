// SPDX-License-Identifier: BSD-2-Clause
//
// ber_counter.v
// =============
//
// Bit-Error-Rate counter. Compares the recovered bits coming out of the
// CDR against the expected bits (driven straight from the transmitter
// side as a checker tap). On every clock edge it increments either the
// total-bit count or the error count.
//
// In a real link the transmitter and receiver don't share a side-channel;
// the receiver instead runs a known PRBS pattern (e.g. PRBS-31) and
// compares against a locally regenerated copy of the same sequence. For
// our behavioral testbench the side-channel works fine and keeps the
// model small.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module ber_counter #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   enable,
    input  wire [NUM_LAMBDAS-1:0] tx_data,
    input  wire [NUM_LAMBDAS-1:0] rx_data,
    output reg  [31:0]            total_bits,
    output reg  [31:0]            error_bits,
    output reg  [NUM_LAMBDAS-1:0] error_per_lambda
);

    integer k;
    reg [NUM_LAMBDAS-1:0] xor_mask;

    always @(posedge clk) begin
        if (rst) begin
            total_bits       <= 32'd0;
            error_bits       <= 32'd0;
            error_per_lambda <= {NUM_LAMBDAS{1'b0}};
        end else if (enable) begin
            xor_mask = tx_data ^ rx_data;
            total_bits <= total_bits + NUM_LAMBDAS;
            // count set bits in xor_mask
            error_bits <= error_bits + $countones(xor_mask);
            error_per_lambda <= error_per_lambda | xor_mask;
        end
    end

endmodule
