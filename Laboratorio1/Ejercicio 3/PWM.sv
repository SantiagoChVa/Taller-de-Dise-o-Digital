module pwm_generator(

    input clk,          
    input [3:0] SW,     // switches SW0-SW3
    output reg LED      // LED

);

reg [16:0] counter = 0;

parameter PERIOD = 100000;   // ≈1 ms 

wire [16:0] duty;

    assign duty = (SW * PERIOD) / 16;

always @(posedge clk)
begin

    // contador
    if(counter >= PERIOD-1)
        counter <= 0;
    else
        counter <= counter + 1;

    // generación de PWM
    if(counter < duty)
        LED <= 1;
    else
        LED <= 0;

end

endmodule
