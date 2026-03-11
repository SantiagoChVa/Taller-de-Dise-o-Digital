module pwm_generator(

    input clk,          
    input [3:0] sw,     // switches SW0-SW3
    output reg led      // LED

);

reg [16:0] counter = 0;

parameter PERIOD = 100000;   // ≈1 ms 

wire [16:0] duty;

assign duty = (sw * PERIOD) / 16;

always @(posedge clk)
begin

    // contador
    if(counter >= PERIOD-1)
        counter <= 0;
    else
        counter <= counter + 1;

    // generación de PWM
    if(counter < duty)
        led <= 1;
    else
        led <= 0;

end

endmodule
