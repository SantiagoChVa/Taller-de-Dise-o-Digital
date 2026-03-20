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

reg  [3:0] SW;
wire [3:0] LED;

integer i;
integer errors = 0;

comp2 uut (
    .SW(SW),
    .LED(LED)
);

initial begin

    $display("Iniciando pruebas del módulo comp2...");
    
    // Probar todos los valores posibles de 4 bits
    for (i = 0; i < 16; i = i + 1) begin
        SW = i[3:0];
        #10;
        if (LED !== (~SW + 1)) begin
            $display("ERROR: SW = %b | LED = %b | Esperado = %b",
                     SW, LED, (~SW + 1));
            errors = errors + 1;
        end
        else begin
            $display("OK: SW = %b | LED = %b",
                     SW, LED);
        end
    end
    // Resultado final
    if (errors == 0)
        $display("Todas las pruebas pasaron correctamente.");
    else
        $display("Se encontraron %0d errores.", errors);
    $finish;
end
endmodule
