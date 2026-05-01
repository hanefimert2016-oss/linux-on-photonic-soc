// SPDX-License-Identifier: BSD-2-Clause
//
// wdm_fabric.v
// ============
//
// Photonic-inspired Wavelength-Division-Multiplexed (WDM) data fabric.
//
// This module is a *behavioral* HDL model of a parallel data interconnect
// inspired by silicon-photonic WDM links. It does NOT model real photonics
// (waveguides, modulators, detectors); it captures the *architectural*
// property of WDM: many independent "wavelength" channels carrying data in
// parallel on the same fabric, all sampled on the same clock edge.
//
// Each wavelength lambda_k is a logically independent bus of DATA_WIDTH bits,
// driven by its own transmitter (TX_k) and read by its own receiver (RX_k).
// A round-robin scheduler emits a unique data word on each lambda every cycle
// so that, in waveform, all NUM_LAMBDAS channels visibly transition in
// parallel — illustrating the high aggregate throughput a real WDM link
// would provide (NUM_LAMBDAS * DATA_WIDTH * f_clk bits/s).
//
// Aggregate throughput @ f_clk = 100 MHz, 8 lambdas, 32 bits = 25.6 Gb/s.
// At higher photonic clock targets (e.g. f_clk = 5 GHz) this scales to
// 1.28 Tb/s — the regime real WDM photonic links operate in.
//
//                              +------------------+
//   tx_data[k] ---> tx_valid ->|                  |-> rx_data[k]
//   (per lambda)    tx_ready  <|   wdm_fabric     |  rx_valid
//                              |                  |  (per lambda)
//                              +------------------+

`timescale 1ns / 1ps

module wdm_fabric #(
    parameter integer NUM_LAMBDAS = 8,    // wavelength channels
    parameter integer DATA_WIDTH  = 32    // bits per channel
) (
    input  wire                                  clk,
    input  wire                                  rst,

    // Per-lambda transmit interface (host -> fabric)
    input  wire [NUM_LAMBDAS*DATA_WIDTH-1:0]     tx_data,
    input  wire [NUM_LAMBDAS-1:0]                tx_valid,
    output wire [NUM_LAMBDAS-1:0]                tx_ready,

    // Per-lambda receive interface (fabric -> host)
    output reg  [NUM_LAMBDAS*DATA_WIDTH-1:0]     rx_data,
    output reg  [NUM_LAMBDAS-1:0]                rx_valid,

    // Optical link health/diagnostic
    output reg  [NUM_LAMBDAS-1:0]                lambda_active,
    output reg  [31:0]                           total_words
);

    // The fabric has zero contention because every lambda is independent.
    // tx_ready is therefore always asserted once we're out of reset.
    assign tx_ready = {NUM_LAMBDAS{~rst}};

    integer i;
    integer popcnt;

    always @(posedge clk) begin
        if (rst) begin
            rx_data       <= {NUM_LAMBDAS*DATA_WIDTH{1'b0}};
            rx_valid      <= {NUM_LAMBDAS{1'b0}};
            lambda_active <= {NUM_LAMBDAS{1'b0}};
            total_words   <= 32'd0;
        end else begin
            popcnt = 0;
            for (i = 0; i < NUM_LAMBDAS; i = i + 1) begin
                if (tx_valid[i]) begin
                    rx_data [i*DATA_WIDTH +: DATA_WIDTH]
                        <= tx_data[i*DATA_WIDTH +: DATA_WIDTH];
                    rx_valid[i]      <= 1'b1;
                    lambda_active[i] <= 1'b1;
                    popcnt = popcnt + 1;
                end else begin
                    rx_valid[i]      <= 1'b0;
                end
            end
            total_words <= total_words + popcnt[31:0];
        end
    end

endmodule
