// SPDX-License-Identifier: BSD-2-Clause
//
// optical_link_tb.v
// =================
//
// Drives the full photonic link end-to-end with PRBS data on each lambda,
// measures BER, and dumps a waveform that shows light flowing from the
// DFB-laser array through the photodetectors back into digital bits.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module optical_link_tb;

    localparam integer NUM_LAMBDAS = `NUM_LAMBDAS;
    localparam integer CLK_PERIOD  = 10;       // 100 MHz testbench clock
    localparam integer SIM_CYCLES  = 512;

    reg                       clk    = 1'b0;
    reg                       rst    = 1'b1;
    reg                       laser_enable = 1'b0;
    reg                       rx_enable    = 1'b0;
    reg  [NUM_LAMBDAS-1:0]    tx_data;
    wire [NUM_LAMBDAS-1:0]    rx_data;
    wire                      cdr_locked;

    wire [NUM_LAMBDAS*64-1:0] laser_intensity_pack;
    wire [NUM_LAMBDAS*64-1:0] modulated_pack;
    wire [NUM_LAMBDAS*64-1:0] bus_intensity_pack;
    wire [63:0]               bus_total_pack;
    wire [NUM_LAMBDAS*64-1:0] after_waveguide_pack;
    wire [NUM_LAMBDAS*64-1:0] after_noise_pack;
    wire [NUM_LAMBDAS*64-1:0] port_intensity_pack;
    wire [NUM_LAMBDAS*64-1:0] tia_voltage_pack;
    wire [NUM_LAMBDAS-1:0]    laser_on;

    optical_link_top #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) dut (
        .clk                  (clk),
        .rst                  (rst),
        .laser_enable         (laser_enable),
        .rx_enable            (rx_enable),
        .tx_data              (tx_data),
        .rx_data              (rx_data),
        .cdr_locked           (cdr_locked),
        .laser_intensity_pack (laser_intensity_pack),
        .modulated_pack       (modulated_pack),
        .bus_intensity_pack   (bus_intensity_pack),
        .bus_total_pack       (bus_total_pack),
        .after_waveguide_pack (after_waveguide_pack),
        .after_noise_pack     (after_noise_pack),
        .port_intensity_pack  (port_intensity_pack),
        .tia_voltage_pack     (tia_voltage_pack),
        .laser_on             (laser_on)
    );

    // ---------------- Decoded real-valued taps for GTKWave ----------------
    // Verilog 'real' wires can be displayed in GTKWave as analog signals.
    real laser0, laser1, laser2, laser3, laser4, laser5, laser6, laser7;
    real mod0, mod1, mod2, mod7;
    real bus0, bus1, bus7, bus_total;
    real after_wg0, after_wg7;
    real after_noise0, after_noise7;
    real port0, port1, port2, port7;
    real tia0, tia7;

    always @* begin
        laser0 = $bitstoreal(laser_intensity_pack[0*64 +: 64]);
        laser1 = $bitstoreal(laser_intensity_pack[1*64 +: 64]);
        laser2 = $bitstoreal(laser_intensity_pack[2*64 +: 64]);
        laser3 = $bitstoreal(laser_intensity_pack[3*64 +: 64]);
        laser4 = $bitstoreal(laser_intensity_pack[4*64 +: 64]);
        laser5 = $bitstoreal(laser_intensity_pack[5*64 +: 64]);
        laser6 = $bitstoreal(laser_intensity_pack[6*64 +: 64]);
        laser7 = $bitstoreal(laser_intensity_pack[7*64 +: 64]);

        mod0 = $bitstoreal(modulated_pack[0*64 +: 64]);
        mod1 = $bitstoreal(modulated_pack[1*64 +: 64]);
        mod2 = $bitstoreal(modulated_pack[2*64 +: 64]);
        mod7 = $bitstoreal(modulated_pack[7*64 +: 64]);

        bus0 = $bitstoreal(bus_intensity_pack[0*64 +: 64]);
        bus1 = $bitstoreal(bus_intensity_pack[1*64 +: 64]);
        bus7 = $bitstoreal(bus_intensity_pack[7*64 +: 64]);
        bus_total = $bitstoreal(bus_total_pack);

        after_wg0   = $bitstoreal(after_waveguide_pack[0*64 +: 64]);
        after_wg7   = $bitstoreal(after_waveguide_pack[7*64 +: 64]);
        after_noise0 = $bitstoreal(after_noise_pack[0*64 +: 64]);
        after_noise7 = $bitstoreal(after_noise_pack[7*64 +: 64]);

        port0 = $bitstoreal(port_intensity_pack[0*64 +: 64]);
        port1 = $bitstoreal(port_intensity_pack[1*64 +: 64]);
        port2 = $bitstoreal(port_intensity_pack[2*64 +: 64]);
        port7 = $bitstoreal(port_intensity_pack[7*64 +: 64]);

        tia0 = $bitstoreal(tia_voltage_pack[0*64 +: 64]);
        tia7 = $bitstoreal(tia_voltage_pack[7*64 +: 64]);
    end

    // -------------------- BER monitor (with TX delay-line) -----------------
    // The pipeline depth from tx_data to rx_data is 5 cycles:
    //     waveguide(1) + noise(1) + CDR sync0(1) + sync1(1) + data_out(1).
    // We delay tx_data by the same amount so the BER counter compares
    // matching bits.
    reg [NUM_LAMBDAS-1:0] tx_d1, tx_d2, tx_d3, tx_d4, tx_d5;
    always @(posedge clk) begin
        tx_d1 <= tx_data;
        tx_d2 <= tx_d1;
        tx_d3 <= tx_d2;
        tx_d4 <= tx_d3;
        tx_d5 <= tx_d4;
    end

    wire [31:0] total_bits;
    wire [31:0] error_bits;
    wire [NUM_LAMBDAS-1:0] error_per_lambda;

    ber_counter #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_ber (
        .clk              (clk),
        .rst              (rst),
        .enable           (rx_enable & cdr_locked),
        .tx_data          (tx_d5),
        .rx_data          (rx_data),
        .total_bits       (total_bits),
        .error_bits       (error_bits),
        .error_per_lambda (error_per_lambda)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------- PRBS data generator --------------------------
    integer i;
    reg [31:0] prbs[0:NUM_LAMBDAS-1];

    initial begin
        for (i = 0; i < NUM_LAMBDAS; i = i + 1)
            prbs[i] = 32'hCAFEBABE ^ (i * 32'h12345678);
        tx_data = {NUM_LAMBDAS{1'b0}};
    end

    always @(posedge clk) begin
        for (i = 0; i < NUM_LAMBDAS; i = i + 1) begin
            // 32-bit LFSR (polynomial x^32 + x^22 + x^2 + x + 1).
            prbs[i] = {prbs[i][30:0],
                       prbs[i][31] ^ prbs[i][21] ^ prbs[i][1] ^ prbs[i][0]};
            tx_data[i] <= prbs[i][0];
        end
    end

    initial begin
        $dumpfile("dump_optical.vcd");
        $dumpvars(0, optical_link_tb);

        $display("[optical_tb] photon-pure link with %0d DFB lasers",
                 NUM_LAMBDAS);
        $display("[optical_tb] symbol rate at TB clk = %0.0f MHz, NRZ",
                 1000.0 / CLK_PERIOD);
        $display("[optical_tb] aggregate (1 bit/symbol) = %0d bits/clk",
                 NUM_LAMBDAS);

        # (CLK_PERIOD * 4);
        rst = 0;
        # (CLK_PERIOD * 2);
        laser_enable = 1;
        # (CLK_PERIOD * 4);
        rx_enable = 1;

        # (CLK_PERIOD * SIM_CYCLES);

        $display("[optical_tb] cdr_locked = %b", cdr_locked);
        $display("[optical_tb] BER: errors=%0d / total=%0d",
                 error_bits, total_bits);
        $display("[optical_tb] error_per_lambda = %b", error_per_lambda);

        if (cdr_locked !== 1'b1) begin
            $display("[optical_tb] FAIL: CDR did not lock");
            $finish;
        end
        if (total_bits < (SIM_CYCLES - 64) * NUM_LAMBDAS) begin
            $display("[optical_tb] FAIL: too few bits transferred");
            $finish;
        end
        if (error_bits != 32'd0) begin
            $display("[optical_tb] FAIL: link is not bit-perfect (errors=%0d)",
                     error_bits);
            $finish;
        end

        $display("[optical_tb] PASS: %0d wavelengths, %0d bits, 0 errors",
                 NUM_LAMBDAS, total_bits);
        $finish;
    end

endmodule
