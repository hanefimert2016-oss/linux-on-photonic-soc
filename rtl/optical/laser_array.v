// SPDX-License-Identifier: BSD-2-Clause
//
// laser_array.v
// =============
//
// Bank of N DFB lasers, each hard-wired to its own logical wavelength λ_k.
// In a real silicon-photonic transmitter this is either:
//
//   - an array of N discrete DFB laser dies bonded onto the photonic IC, or
//   - a single quantum-cascade comb laser that emits N evenly-spaced lines
//     simultaneously and is split downstream.
//
// Either way, the digital-side abstraction is the same: NUM_LAMBDAS
// independent CW optical outputs, each at full laser power.
//
// THIS IS WHAT PROVIDES THE THROUGHPUT SCALING. With N lasers and a
// per-laser symbol rate of f_baud, the aggregate is N*f_baud bits/s — and
// because each laser drives its own modulator (modulator_bank.v) there is
// **no contention** between channels. This is the architectural reason
// optical interconnects break the bandwidth-density wall that purely
// electrical buses hit.
//
// Output: packed bit vector. lane k's intensity is at intensity_pack[k*64+:64]
// in IEEE-754 form (use $bitstoreal at the consumer).

`timescale 1ns / 1ps
`include "optical_constants.vh"

module laser_array #(
    parameter integer NUM_LAMBDAS = `NUM_LAMBDAS
) (
    input  wire                    enable,
    output reg  [NUM_LAMBDAS-1:0]  laser_on,
    output reg  [NUM_LAMBDAS*64-1:0] intensity_pack
);

    integer k;
    real    p;

    always @* begin
        for (k = 0; k < NUM_LAMBDAS; k = k + 1) begin
            laser_on[k] = enable;
            p = enable ? `LASER_POWER : 0.0;
            intensity_pack[k*64 +: 64] = $realtobits(p);
        end
    end

endmodule
