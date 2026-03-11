`timescale 1ns / 1ps

module testbench;

reg clk;
reg [3:0] level;
wire pwm_out;

integer i;

// Instancia del módulo a probar
pwm_generator uut (
    .clk(clk),
    .level(level),
    .pwm_out(pwm_out)
);


// Generador de clock 
always #5 clk = ~clk;


// Inicialización
initial begin

    clk = 0;
    level = 0;

end


// Estímulos de prueba
initial begin

    
    #20;

    // recorrer todos los valores
    for(i = 0; i < 16; i = i + 1) begin
        
        level = i;

        
        repeat(120000) @(posedge clk);

    end

    

end

endmodule
