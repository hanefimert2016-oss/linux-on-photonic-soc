// SPDX-License-Identifier: BSD-2-Clause
//
// ring_drop_filter.v
// ==================
//
// Microring drop filter — alternative to the AWG for wavelength
// demultiplexing. A single microring tuned to λ_k taps that one wavelength
// off the bus into a "drop" port and lets the remaining wavelengths
// continue down the through port.
//
// In a real chip you cascade NUM_LAMBDAS of these in series, each tuned to
// one wavelength, to demultiplex an entire WDM bus. Microring drops are
// typically smaller than AWGs but more sensitive to temperature drift.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module ring_drop_filter #(
    parameter integer LAMBDA_ID  = 0,
    parameter real    EXTRACTION = 0.95
) (
    input  real       in_intensity,
    input  wire [7:0] in_lambda_id,
    output real       drop_intensity,
    output real       through_intensity
);

    wire match = (in_lambda_id == LAMBDA_ID[7:0]);

    assign drop_intensity    = match ? in_intensity * EXTRACTION : 0.0;
    assign through_intensity = match ? in_intensity * (1.0 - EXTRACTION)
                                     : in_intensity;

endmodule
