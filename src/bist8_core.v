`timescale 1ns / 1ps
// =============================================================================
// Module:      bist8_core
// Project:     BIST-8: Built-In Self-Test for 8-bit CLA Adder
// Description: Core BIST logic. Instantiable in both TT and FPGA wrappers.
//
// Architecture:
//   - CUT:  8-bit Carry-Lookahead Adder (2x 4-bit CLA groups)
//   - TPG:  12-bit LFSR (poly x^12+x^11+x^10+x^4+1), period 4095
//            a_cut = lfsr[7:0], b_cut = {4'b0, lfsr[11:8]}
//   - MISR: 16-bit (poly x^16+x^15+x^2+1)
//            data input = {carry_out, sum[7:0]} = 9 bits
//   - FSM:  IDLE -> BIST_RUN -> COMPARE -> DONE
//   - Golden signature: 0xCCA5 (verified via Python simulation)
//
// Fault injection: forces bit3 of sum to 0 (stuck-at-0) when fault_inject=1
//
// Author:      Mario Garcia Jimenez - IMSE-CNM-CSIC / Universidad de Sevilla
// =============================================================================

module bist8_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bist_en,
    input  wire        fault_inject,
    input  wire [7:0]  a_in,
    input  wire [7:0]  b_in,
    output wire [7:0]  sum_out,
    output wire        cout_out,
    output reg         bist_pass,
    output reg         bist_fail,
    output reg         bist_done,
    output reg  [11:0] cycle_count
);

    // =========================================================================
    // Parametros
    // =========================================================================
    localparam GOLDEN_SIG  = 16'hCF77;
    localparam LFSR_SEED   = 12'hACE;
    localparam BIST_CYCLES = 12'd4095;

    localparam IDLE     = 2'd0;
    localparam BIST_RUN = 2'd1;
    localparam COMPARE  = 2'd2;
    localparam DONE     = 2'd3;

    // =========================================================================
    // CLA 8 bits (dos grupos de 4 bits)
    // =========================================================================
    wire [7:0] a_cut, b_cut;

    // Grupo bajo [3:0]
    wire [3:0] g_lo = a_cut[3:0] & b_cut[3:0];
    wire [3:0] p_lo = a_cut[3:0] | b_cut[3:0];
    wire [4:0] c_lo;

    assign c_lo[0] = 1'b0;
    assign c_lo[1] = g_lo[0] | (p_lo[0] & c_lo[0]);
    assign c_lo[2] = g_lo[1] | (p_lo[1] & g_lo[0]) | (p_lo[1] & p_lo[0] & c_lo[0]);
    assign c_lo[3] = g_lo[2] | (p_lo[2] & g_lo[1]) | (p_lo[2] & p_lo[1] & g_lo[0])
                              | (p_lo[2] & p_lo[1] & p_lo[0] & c_lo[0]);
    assign c_lo[4] = g_lo[3] | (p_lo[3] & g_lo[2]) | (p_lo[3] & p_lo[2] & g_lo[1])
                              | (p_lo[3] & p_lo[2] & p_lo[1] & g_lo[0])
                              | (p_lo[3] & p_lo[2] & p_lo[1] & p_lo[0] & c_lo[0]);

    wire [3:0] sum_lo = a_cut[3:0] ^ b_cut[3:0] ^ c_lo[3:0];

    // Grupo alto [7:4]
    wire [3:0] g_hi = a_cut[7:4] & b_cut[7:4];
    wire [3:0] p_hi = a_cut[7:4] | b_cut[7:4];
    wire [4:0] c_hi;

    assign c_hi[0] = c_lo[4];
    assign c_hi[1] = g_hi[0] | (p_hi[0] & c_hi[0]);
    assign c_hi[2] = g_hi[1] | (p_hi[1] & g_hi[0]) | (p_hi[1] & p_hi[0] & c_hi[0]);
    assign c_hi[3] = g_hi[2] | (p_hi[2] & g_hi[1]) | (p_hi[2] & p_hi[1] & g_hi[0])
                              | (p_hi[2] & p_hi[1] & p_hi[0] & c_hi[0]);
    assign c_hi[4] = g_hi[3] | (p_hi[3] & g_hi[2]) | (p_hi[3] & p_hi[2] & g_hi[1])
                              | (p_hi[3] & p_hi[2] & p_hi[1] & g_hi[0])
                              | (p_hi[3] & p_hi[2] & p_hi[1] & p_hi[0] & c_hi[0]);

    wire [3:0] sum_hi  = a_cut[7:4] ^ b_cut[7:4] ^ c_hi[3:0];
    wire [7:0] sum_clean = {sum_hi, sum_lo};

    // =========================================================================
    // Inyeccion de fallo (SA0 en bit 3)
    // =========================================================================
    wire [7:0] sum_cut = fault_inject ? (sum_clean & 8'hF7) : sum_clean;

    // =========================================================================
    // LFSR 12 bits: x^12 + x^11 + x^10 + x^4 + 1
    // =========================================================================
    reg [11:0] lfsr;
    wire lfsr_fb = lfsr[11] ^ lfsr[10] ^ lfsr[9] ^ lfsr[3];

    // =========================================================================
    // MISR 16 bits: x^16 + x^15 + x^2 + 1
    // Implementacion correcta:
    //   fb     = misr[0]
    //   new[15] = fb
    //   new[14] = misr[15] ^ fb
    //   new[13:2] = misr[14:3]
    //   new[1]  = misr[2] ^ fb
    //   new[0]  = misr[1]
    //   new XOR= {7'b0, data9}
    // =========================================================================
    reg  [15:0] misr;
    wire [8:0]  misr_in = {c_hi[4], sum_cut};  // 9 bits: carry + suma
    wire        misr_fb = misr[0];

    wire [15:0] misr_shifted = {
        misr_fb,                    // bit 15
        misr[15] ^ misr_fb,         // bit 14 (tap x^15)
        misr[14:3],                 // bits 13:2
        misr[2] ^ misr_fb,          // bit 1 (tap x^2)
        misr[1]                     // bit 0
    };

    wire [15:0] misr_next = misr_shifted ^ {7'b0, misr_in};

    // =========================================================================
    // Mux operandos CUT
    // =========================================================================
    assign a_cut = bist_en ? lfsr[7:0]          : a_in;
    assign b_cut = bist_en ? {4'b0, lfsr[11:8]} : b_in;

    assign sum_out  = sum_clean;
    assign cout_out = c_hi[4];

    // =========================================================================
    // FSM
    // =========================================================================
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            lfsr        <= LFSR_SEED;
            misr        <= 16'h0000;
            cycle_count <= 12'd0;
            bist_pass   <= 1'b0;
            bist_fail   <= 1'b0;
            bist_done   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    bist_pass   <= 1'b0;
                    bist_fail   <= 1'b0;
                    bist_done   <= 1'b0;
                    cycle_count <= 12'd0;
                    lfsr        <= LFSR_SEED;
                    misr        <= 16'h0000;
                    if (bist_en)
                        state <= BIST_RUN;
                end

                BIST_RUN: begin
                    lfsr        <= {lfsr[10:0], lfsr_fb};
                    misr        <= misr_next;
                    cycle_count <= cycle_count + 1;
                    if (cycle_count == BIST_CYCLES - 1)
                        state <= COMPARE;
                end

                COMPARE: begin
                    bist_done <= 1'b1;
                    if (misr == GOLDEN_SIG) begin
                        bist_pass <= 1'b1;
                        bist_fail <= 1'b0;
                    end else begin
                        bist_pass <= 1'b0;
                        bist_fail <= 1'b1;
                    end
                    state <= DONE;
                end

                DONE: begin
                    if (!bist_en)
                        state <= IDLE;
                end
            endcase
        end
    end

endmodule
