// SPDX-License-Identifier: BSD-2-Clause
//
// wdm_tb.v
// ========
//
// Icarus Verilog testbench that drives the WDM fabric through the
// round-robin scheduler and dumps a waveform to dump.vcd. Open with:
//
//   gtkwave dump.vcd scripts/wdm.gtkw
//
// to see all NUM_LAMBDAS wavelengths transitioning in parallel.

`timescale 1ns / 1ps

module wdm_tb;

    localparam integer NUM_LAMBDAS = 8;
    localparam integer DATA_WIDTH  = 32;
    localparam integer CLK_PERIOD  = 10;   // 100 MHz simulated clock
    localparam integer SIM_CYCLES  = 256;

    reg clk = 0;
    reg rst = 1;
    reg enable = 0;

    wire [NUM_LAMBDAS*DATA_WIDTH-1:0] tx_data;
    wire [NUM_LAMBDAS-1:0]            tx_valid;
    wire [NUM_LAMBDAS-1:0]            tx_ready;

    wire [NUM_LAMBDAS*DATA_WIDTH-1:0] rx_data;
    wire [NUM_LAMBDAS-1:0]            rx_valid;
    wire [NUM_LAMBDAS-1:0]            lambda_active;
    wire [31:0]                       total_words;
    wire [31:0]                       cycle_counter;

    // Per-lambda signal aliases for readable waveforms in GTKWave.
    wire [DATA_WIDTH-1:0] lambda0_tx = tx_data[0*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda1_tx = tx_data[1*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda2_tx = tx_data[2*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda3_tx = tx_data[3*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda4_tx = tx_data[4*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda5_tx = tx_data[5*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda6_tx = tx_data[6*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda7_tx = tx_data[7*DATA_WIDTH +: DATA_WIDTH];

    wire [DATA_WIDTH-1:0] lambda0_rx = rx_data[0*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda1_rx = rx_data[1*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda2_rx = rx_data[2*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda3_rx = rx_data[3*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda4_rx = rx_data[4*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda5_rx = rx_data[5*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda6_rx = rx_data[6*DATA_WIDTH +: DATA_WIDTH];
    wire [DATA_WIDTH-1:0] lambda7_rx = rx_data[7*DATA_WIDTH +: DATA_WIDTH];

    wdm_scheduler #(
        .NUM_LAMBDAS(NUM_LAMBDAS),
        .DATA_WIDTH (DATA_WIDTH)
    ) sched (
        .clk          (clk),
        .rst          (rst),
        .enable       (enable),
        .tx_ready     (tx_ready),
        .tx_data      (tx_data),
        .tx_valid     (tx_valid),
        .cycle_counter(cycle_counter)
    );

    wdm_fabric #(
        .NUM_LAMBDAS(NUM_LAMBDAS),
        .DATA_WIDTH (DATA_WIDTH)
    ) fabric (
        .clk          (clk),
        .rst          (rst),
        .tx_data      (tx_data),
        .tx_valid     (tx_valid),
        .tx_ready     (tx_ready),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .lambda_active(lambda_active),
        .total_words  (total_words)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, wdm_tb);

        $display("[wdm_tb] Photonic-inspired WDM fabric simulation");
        $display("[wdm_tb] %0d wavelengths, %0d-bit each", NUM_LAMBDAS, DATA_WIDTH);
        $display("[wdm_tb] clock = %0d ns (%0.0f MHz simulated)",
                 CLK_PERIOD, 1000.0/CLK_PERIOD);
        $display("[wdm_tb] aggregate = %0d bits/cycle = %0.2f Gb/s @ 100 MHz",
                 NUM_LAMBDAS*DATA_WIDTH,
                 (NUM_LAMBDAS*DATA_WIDTH*100.0)/1000.0);

        # (CLK_PERIOD * 4);
        rst = 0;
        # (CLK_PERIOD * 2);
        enable = 1;

        # (CLK_PERIOD * SIM_CYCLES);

        $display("[wdm_tb] simulation finished, total_words=%0d (expected ~%0d)",
                 total_words, SIM_CYCLES * NUM_LAMBDAS);

        if (total_words < (SIM_CYCLES - 4) * NUM_LAMBDAS) begin
            $display("[wdm_tb] FAIL: too few words transferred");
            $finish(1);
        end

        $display("[wdm_tb] PASS: all %0d wavelengths active in parallel",
                 NUM_LAMBDAS);
        $finish;
    end

endmodule
