module pwm_generator(

    input logic clk,          
    input logic [3:0] SW,     // switches SW0-SW3
    output logic LED      // LED

);

logic [16:0] counter = 0;

parameter int PERIOD = 100000;   // ≈1 ms 

logic [16:0] duty;

    assign duty = (SW * PERIOD) / 16;

always_ff @(posedge clk)
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
