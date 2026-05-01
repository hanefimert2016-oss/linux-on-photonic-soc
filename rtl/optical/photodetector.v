// SPDX-License-Identifier: BSD-2-Clause
//
// photodetector.v
// ===============
//
// Behavioral model of a high-speed germanium-on-silicon photodetector —
// the device that converts optical intensity back into electrical current.
//
// In a real PD, photons release electron-hole pairs in proportion to the
// incoming power: I_photo = R * P_optical, where R is the responsivity
// (~0.8 A/W at 1310 nm). We collapse all of that into "photo_current is
// proportional to intensity_in".
//
// We also slice the analog photo-current at a fixed threshold to recover
// the digital bit. The threshold determines the noise margin and is
// usually set midway between the "1" and "0" optical levels.

`timescale 1ns / 1ps
`include "optical_constants.vh"

module photodetector #(
    parameter real RESPONSIVITY = 1.0,
    parameter real THRESHOLD    = `PD_THRESHOLD
) (
    input  real intensity_in,
    output real photo_current,
    output wire data_out
);

    assign photo_current = intensity_in * RESPONSIVITY;
    assign data_out      = (intensity_in > THRESHOLD);

endmodule
