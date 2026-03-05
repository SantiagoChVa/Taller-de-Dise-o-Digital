`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.03.2026 10:49:14
// Design Name: 
// Module Name: testbench
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


module testbench;

reg [3:0] SW;
wire [3:0] LED;

comp2 uut (
    .SW(SW),
    .LED(LED)
);

initial begin

    SW = 4'b0000;
    #10 SW = 4'b0001;
    #10 SW = 4'b0010;
    #10 SW = 4'b0101;
    #10 SW = 4'b1010;
    #10 SW = 4'b1111;

    #10 $finish;

end

endmodule
