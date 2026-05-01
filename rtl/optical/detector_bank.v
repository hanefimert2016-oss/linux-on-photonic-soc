// SPDX-License-Identifier: BSD-2-Clause
//
// detector_bank.v
// ===============
//
// Bank of N photodetector + TIA pairs. Each lane recovers the data on its
// own wavelength independently; this is the receiver-side equivalent of
// modulator_bank.v. A real silicon-photonic receiver uses germanium-on-
// silicon p-i-n photodiodes followed by transimpedance amplifiers (TIA).

`timescale 1ns / 1ps
`include "optical_constants.vh"

module detector_bank #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS,
    parameter real    TIA_GAIN    = 4.0
) (
    input  wire [NUM_LAMBDAS*64-1:0] port_intensity_pack,
    output reg  [NUM_LAMBDAS*64-1:0] tia_voltage_pack,
    output reg  [NUM_LAMBDAS-1:0]    data_out
);

    integer k;
    real    p_in, photo_curr, v_out;

    always @* begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            p_in       = $bitstoreal(port_intensity_pack[k*64 +: 64]);
            // Photodetector: light -> photo-current (responsivity = 1.0).
            photo_curr = p_in;
            // TIA: photo-current -> voltage.
            v_out      = photo_curr * TIA_GAIN;
            tia_voltage_pack[k*64 +: 64] = $realtobits(v_out);
            // Slicer: digital decision against threshold.
            data_out[k] = (p_in > `PD_THRESHOLD);
        end
    end

endmodule
