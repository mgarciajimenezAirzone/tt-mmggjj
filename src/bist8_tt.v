`timescale 1ns / 1ps
// =============================================================================
// Module:      tt_um_mgj_bist8
// Project:     BIST-8: Built-In Self-Test for 8-bit CLA Adder
// Description: Tiny Tapeout wrapper. Interfaz estandar TT04+.
//
// Pin mapping:
//   ui_in[0]    -> bist_en       (activa modo BIST)
//   ui_in[1]    -> fault_inject  (inyecta SA0 en bit3)
//   ui_in[7:2]  -> a_in[5:0]    (operando A bits bajos, modo normal)
//   uio_in[7:0] -> {b_in[7:0]}  (operando B completo, modo normal)
//              *  uio_in[7:6] = a_in[7:6] (bits altos de A)
//
//   uo_out[0]   -> bist_pass
//   uo_out[1]   -> bist_fail
//   uo_out[2]   -> bist_done
//   uo_out[7:3] -> sum_out[7:3] (5 bits altos suma, modo normal)
//
//   uio_out[7:0]-> cycle_count[7:0] (contador ciclos BIST)
//   uio_oe      -> 0xFF en BIST, 0x00 en normal (uio como salida en BIST)
//
// Author:      Mario Garcia Jimenez - IMSE-CNM-CSIC / Universidad de Sevilla
// =============================================================================

module tt_um_mgj_bist8 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire        bist_en      = ui_in[0];
    wire        fault_inject = ui_in[1];
    wire [7:0]  a_in         = {uio_in[7:6], ui_in[7:2]};
    wire [7:0]  b_in         = uio_in[5:0] & 8'h3F | {2'b00, uio_in[5:0]};

    wire [7:0]  sum_out;
    wire        cout_out;
    wire        bist_pass, bist_fail, bist_done;
    wire [11:0] cycle_count;

    bist8_core core (
        .clk         (clk),
        .rst_n       (rst_n),
        .bist_en     (bist_en),
        .fault_inject(fault_inject),
        .a_in        (a_in),
        .b_in        (b_in),
        .sum_out     (sum_out),
        .cout_out    (cout_out),
        .bist_pass   (bist_pass),
        .bist_fail   (bist_fail),
        .bist_done   (bist_done),
        .cycle_count (cycle_count)
    );

    assign uo_out  = {sum_out[7:3], bist_done, bist_fail, bist_pass};
    assign uio_out = cycle_count[7:0];
    assign uio_oe  = bist_en ? 8'hFF : 8'h00;

endmodule
