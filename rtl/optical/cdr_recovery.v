// SPDX-License-Identifier: BSD-2-Clause
//
// cdr_recovery.v
// ==============
//
// Clock & Data Recovery (CDR). At the receiver the recovered data stream
// is asynchronous to the local clock, so we need a CDR to find the bit
// boundaries and produce a re-timed data stream.
//
// Behavioral model: we treat `clk` as an over-sampling clock, sample
// `data_in` on the rising edge, and pass it through a 2-flop synchronizer
// — that is roughly what a real bang-bang CDR's "data slice" path does
// once the phase loop has locked.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module cdr_recovery #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire                   clk,
    input  wire                   rst,
    input  wire [NUM_LAMBDAS-1:0] data_in,
    output reg  [NUM_LAMBDAS-1:0] data_out,
    output reg                    locked
);

    reg [NUM_LAMBDAS-1:0] sync0, sync1;
    reg [3:0]             lock_cnt;

    always @(posedge clk) begin
        if (rst) begin
            sync0    <= {NUM_LAMBDAS{1'b0}};
            sync1    <= {NUM_LAMBDAS{1'b0}};
            data_out <= {NUM_LAMBDAS{1'b0}};
            lock_cnt <= 4'd0;
            locked   <= 1'b0;
        end else begin
            sync0 <= data_in;
            sync1 <= sync0;
            data_out <= sync1;
            if (!locked) begin
                lock_cnt <= lock_cnt + 4'd1;
                if (&lock_cnt) locked <= 1'b1;
            end
        end
    end

endmodule
