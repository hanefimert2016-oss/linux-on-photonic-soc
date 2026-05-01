// SPDX-License-Identifier: BSD-2-Clause
//
// optical_waveguide.v
// ===================
//
// Behavioral model of a passive silicon-photonic waveguide. A real waveguide:
//
//   - propagates light at ~c/3.5 = 8.6 cm/ns (silicon group index ~3.5),
//     so a 1 cm bus has roughly 0.12 ns flight time,
//   - has propagation loss of ~0.5-2 dB/cm in silicon, much less in glass
//     fibre. We model it as a fractional power transmission per "hop".
//
// Each wavelength is attenuated independently and identically (we ignore
// wavelength-dependent loss to keep the model simple).
//
// We register the output on the rising clock edge so the waveform clearly
// shows a pipelined hop in GTKWave; this is also what makes the model
// synthesisable.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module optical_waveguide #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire                       clk,
    input  wire [NUM_LAMBDAS*64-1:0]  intensity_in_pack,
    output reg  [NUM_LAMBDAS*64-1:0]  intensity_out_pack
);

    integer k;
    real    p_in, p_out;

    always @(posedge clk) begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            p_in  = $bitstoreal(intensity_in_pack[k*64 +: 64]);
            p_out = p_in * `WG_LOSS;
            intensity_out_pack[k*64 +: 64] <= $realtobits(p_out);
        end
    end

endmodule
