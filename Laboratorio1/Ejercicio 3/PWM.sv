module pwm_generator(

    input clk,
    input [3:0] level,     // entrada
    output reg pwm_out

);

reg [16:0] counter = 0;

parameter PERIOD = 100000;   // 1 ms 

wire [16:0] duty;

assign duty = (level * PERIOD) / 16;

always @(posedge clk)
begin

    if(counter >= PERIOD-1)    // contador
        counter <= 0;
    else
        counter <= counter + 1;

    if(counter < duty)       // funcion de la salida 
        pwm_out <= 1;
    else
        pwm_out <= 0;

end

endmodule
