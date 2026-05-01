// SPDX-License-Identifier: BSD-2-Clause
//
// awg_demux.v
// ===========
//
// Arrayed Waveguide Grating (AWG) demultiplexer. An AWG consists of two
// star couplers connected by an array of waveguides whose lengths increase
// in equal increments — a literal optical Fourier transform that routes
// each input wavelength to its own output port.
//
// Behavioral model:
//
//   port[k] = bus[k] * INSERTION + sum_{j != k} bus[j] * CROSSTALK
//
// i.e. the dominant signal on output k is its own wavelength, but a small
// CROSSTALK fraction of the neighbouring channels leaks into it. CROSSTALK
// is what limits how many channels you can actually pack into a single
// fibre / waveguide before the BER blows up.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module awg_demux #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire [NUM_LAMBDAS*64-1:0] bus_intensity_pack,
    output reg  [NUM_LAMBDAS*64-1:0] port_intensity_pack
);

    integer k, j;
    real    bus_arr [0:`NUM_LAMBDAS-1];
    real    sum_other;
    real    p_out;

    always @* begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            bus_arr[k] = $bitstoreal(bus_intensity_pack[k*64 +: 64]);
        end
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            sum_other = 0.0;
            for (j = 0; j < NUM_LAMBDAS; j = j + 1) begin
                if (j != k) sum_other = sum_other + bus_arr[j];
            end
            p_out = bus_arr[k] * `DEMUX_LOSS + sum_other * `CROSSTALK;
            port_intensity_pack[k*64 +: 64] = $realtobits(p_out);
        end
    end

endmodule
