`timescale 1ns / 1ps

module TESTBENCH;

reg CLK;
reg [3:0] SW;
wire LED;

integer I;

PWM_GENERATOR UUT(
    .CLK(CLK),
    .SW(SW),
    .LED(LED)
);

always #5 CLK = ~CLK;

initial begin
    CLK = 0;
end

initial begin

    SW = 0;

    for(I = 0; I < 16; I = I + 1) begin
        SW = I;
        repeat(120000) @(posedge CLK);
    end

    $finish;

end

endmodule
