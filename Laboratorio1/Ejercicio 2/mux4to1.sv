`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.03.2026
// Module Name: mux4to1
// Description: Multiplexor 4 a 1 parametrizable
//////////////////////////////////////////////////////////////////////////////////

module mux4to1 #(
    parameter int unsigned WIDTH = 4
)(
    input  logic [WIDTH-1:0] in0,
    input  logic [WIDTH-1:0] in1,
    input  logic [WIDTH-1:0] in2,
    input  logic [WIDTH-1:0] in3,
    input  logic [1:0] sel,
    output logic [WIDTH-1:0] y
);

    always_comb begin
        y = '0;

        case(sel)
            2'b00: y = in0;
            2'b01: y = in1;
            2'b10: y = in2;
            2'b11: y = in3;
            default: y = '0;
        endcase
    end

endmodule