`timescale 1ns / 1ps

module testbench;

reg clk;
reg [3:0] sw;
wire led;

integer i;

pwm_generator uut(
    .clk(clk),
    .sw(sw),
    .led(led)
);

always #5 clk = ~clk;

initial begin
    clk = 0;
end

initial begin

    sw = 0;

    for(i = 0; i < 16; i = i + 1) begin
        sw = i;
        repeat(120000) @(posedge clk);
    end

    //$finish;

end

endmodule
