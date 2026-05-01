// SPDX-License-Identifier: BSD-2-Clause
//
// ring_modulator.v
// ================
//
// Microring resonator modulator — alternative to the MZ modulator. A real
// microring (typically 5-20 μm diameter in silicon) is a tiny racetrack
// waveguide that resonates only at its design wavelength λ_ring. When the
// ring is "on resonance" the light is pulled into the ring (and lost / sent
// to a drop port), so the through port goes dark = "0". When the ring is
// "off resonance" (electrically detuned by the modulating voltage) the
// light passes straight through = "1".
//
// Because the ring is wavelength-selective it ONLY modulates the channel
// it is tuned to — light at other wavelengths passes through unaffected.
// This is what makes WDM modulator banks compact in silicon: you can put
// N rings on the same bus waveguide, each tuned to its own λ_k.
//
// Behavioral model: same I/O contract as mz_modulator, but exposes the
// `lambda_match` parameter so a top-level can wire several ring_modulators
// onto the same shared optical bus and only have one of them respond.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module ring_modulator #(
    parameter integer LAMBDA_ID = 0
) (
    input  wire       data_in,
    input  real       intensity_in,
    input  wire [7:0] lambda_in_id,
    output real       intensity_out
);

    // If this ring is tuned to the incoming wavelength, modulate it,
    // otherwise pass the light through unchanged.
    wire match = (lambda_in_id == LAMBDA_ID[7:0]);

    assign intensity_out = match ? (data_in ? intensity_in
                                            : intensity_in * `MOD_ER)
                                 : intensity_in;

endmodule
