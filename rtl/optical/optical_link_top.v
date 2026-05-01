// SPDX-License-Identifier: BSD-2-Clause
//
// optical_link_top.v
// ==================
//
// Top-level integration of the photonic-pure optical link. The chain is:
//
//   laser_array  -->  modulator_bank  -->  wavelength_mux  -->
//   optical_waveguide  -->  noise_source  -->  awg_demux  -->
//   detector_bank  -->  cdr_recovery  -->  rx_data
//
// Aggregate bandwidth = NUM_LAMBDAS * f_baud * 1 bit/symbol.
// At NUM_LAMBDAS=8 and f_baud = 1 GHz this is 8 Gb/s in pure WDM-NRZ; with
// 16 lasers it is 16 Gb/s; with realistic PAM-4 modulation the same lasers
// deliver double that. The behavioral RTL captures the architectural
// scaling, not the physical line rate.
//
// The complete data path is N independent lanes of "light" with NO shared
// transistor logic between the modulator bank and the photodetector bank
// — that is the entire point of the photonic interconnect.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module optical_link_top #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       laser_enable,
    input  wire                       rx_enable,
    input  wire [NUM_LAMBDAS-1:0]     tx_data,
    output wire [NUM_LAMBDAS-1:0]     rx_data,
    output wire                       cdr_locked,
    // Diagnostic taps (packed real bus form, k*64 +: 64 = lambda k).
    output wire [NUM_LAMBDAS*64-1:0]  laser_intensity_pack,
    output wire [NUM_LAMBDAS*64-1:0]  modulated_pack,
    output wire [NUM_LAMBDAS*64-1:0]  bus_intensity_pack,
    output wire [63:0]                bus_total_pack,
    output wire [NUM_LAMBDAS*64-1:0]  after_waveguide_pack,
    output wire [NUM_LAMBDAS*64-1:0]  after_noise_pack,
    output wire [NUM_LAMBDAS*64-1:0]  port_intensity_pack,
    output wire [NUM_LAMBDAS*64-1:0]  tia_voltage_pack,
    output wire [NUM_LAMBDAS-1:0]     laser_on
);

    // 1) Laser array: N independent CW DFB sources.
    laser_array #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_lasers (
        .enable        (laser_enable),
        .laser_on      (laser_on),
        .intensity_pack(laser_intensity_pack)
    );

    // 2) Modulator bank: encode one data bit per lambda by amplitude.
    modulator_bank #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_mods (
        .tx_data            (tx_data),
        .intensity_in_pack  (laser_intensity_pack),
        .intensity_out_pack (modulated_pack)
    );

    // 3) Wavelength MUX: combine lambdas onto a single waveguide bus.
    wavelength_mux #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_mux (
        .intensity_in_pack  (modulated_pack),
        .bus_intensity_pack (bus_intensity_pack),
        .bus_total_pack     (bus_total_pack)
    );

    // 4) Waveguide propagation: pipelined hop, fixed loss.
    optical_waveguide #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_wg (
        .clk                (clk),
        .intensity_in_pack  (bus_intensity_pack),
        .intensity_out_pack (after_waveguide_pack)
    );

    // 5) Add shot/thermal noise on top of the optical bus.
    noise_source #(
        .NUM_LAMBDAS(NUM_LAMBDAS),
        .AMPLITUDE  (0.02)
    ) u_noise (
        .clk                (clk),
        .intensity_in_pack  (after_waveguide_pack),
        .intensity_out_pack (after_noise_pack)
    );

    // 6) AWG demux: split the single waveguide back into N lanes (with
    //    a small inter-lambda crosstalk term).
    awg_demux #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_demux (
        .bus_intensity_pack  (after_noise_pack),
        .port_intensity_pack (port_intensity_pack)
    );

    // 7) Detector bank: PD + TIA per lambda, with a slicer for the digital
    //    decision.
    wire [NUM_LAMBDAS-1:0] raw_data_w;
    detector_bank #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_rx (
        .port_intensity_pack (port_intensity_pack),
        .tia_voltage_pack    (tia_voltage_pack),
        .data_out            (raw_data_w)
    );

    // 8) CDR: 2-flop synchroniser + lock counter; produces the final
    //    re-timed RX data on the system clock.
    cdr_recovery #(
        .NUM_LAMBDAS(NUM_LAMBDAS)
    ) u_cdr (
        .clk      (clk),
        .rst      (rst | ~rx_enable),
        .data_in  (raw_data_w),
        .data_out (rx_data),
        .locked   (cdr_locked)
    );

endmodule
