`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.03.2026 10:48:03
// Design Name: 
// Module Name: Comp2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module comp2 (
    input  [3:0] SW,
    output [3:0] LED
);

assign LED = ~SW + 1;

endmodule
