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


// Generador de clock (100 MHz)
always #5 clk = ~clk;


// Inicialización
initial begin

    clk = 0;
    level = 0;

end


// Estímulos de prueba
initial begin

    // esperar un poco al inicio
    #20;

    // recorrer todos los valores de 4 bits
    for(i = 0; i < 16; i = i + 1) begin
        
        level = i;

        // esperar tiempo suficiente para ver el PWM
        repeat(120000) @(posedge clk);

    end

    // detener simulación
   // $stop;

end

endmodule
