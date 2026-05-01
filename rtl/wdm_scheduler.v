// SPDX-License-Identifier: BSD-2-Clause
//
// wdm_scheduler.v
// ===============
//
// A simple round-robin pattern generator for the WDM fabric. Every cycle it
// emits a unique data word on each of NUM_LAMBDAS wavelengths so that the
// resulting waveform clearly shows independent parallel channels — analogous
// to N independent laser wavelengths simultaneously crossing the same
// photonic waveguide.

`timescale 1ns / 1ps

module wdm_scheduler #(
    parameter integer NUM_LAMBDAS = 8,
    parameter integer DATA_WIDTH  = 32
) (
    input  wire                                  clk,
    input  wire                                  rst,
    input  wire                                  enable,
    input  wire [NUM_LAMBDAS-1:0]                tx_ready,
    output reg  [NUM_LAMBDAS*DATA_WIDTH-1:0]     tx_data,
    output reg  [NUM_LAMBDAS-1:0]                tx_valid,
    output reg  [31:0]                           cycle_counter
);

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            tx_data       <= {NUM_LAMBDAS*DATA_WIDTH{1'b0}};
            tx_valid      <= {NUM_LAMBDAS{1'b0}};
            cycle_counter <= 32'd0;
        end else if (enable) begin
            cycle_counter <= cycle_counter + 32'd1;
            for (i = 0; i < NUM_LAMBDAS; i = i + 1) begin
                // Each lambda gets a distinct payload that depends on both
                // its index and the global cycle counter, so the waveform
                // shows parallel-but-independent activity.
                tx_data[i*DATA_WIDTH +: DATA_WIDTH]
                    <= {16'hC0DE,
                        cycle_counter[7:0],
                        i[3:0], 4'h0};
                tx_valid[i] <= tx_ready[i];
            end
        end else begin
            tx_valid <= {NUM_LAMBDAS{1'b0}};
        end
    end

endmodule
