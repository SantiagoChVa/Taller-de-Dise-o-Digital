`timescale 1ns/1ps

module tb_core_rom;

    // Señales
    logic clk;
    logic rst;

    logic [31:0] prog_addr;
    logic [31:0] prog_data;

    logic [31:0] data_addr;
    logic [31:0] data_out;
    logic [31:0] data_in;
    logic        data_we;

    // Clock (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset
    initial begin
        rst = 1;
        #100;
        rst = 0;
    end

    // ROM (tu IP de Vivado)
    rom_programa u_rom (
        .clka  (clk),
        .rsta  (rst),
        .addra (prog_addr[10:2]),
        .douta (prog_data)
        // ignoramos rsta_busy aquí
    );

    // CORE (wrapper original SIN cambios)
    riscv_core_wrapper u_core (
        .clk_i         (clk),
        .rst_i         (rst),

        .ProgAddress_o (prog_addr),
        .ProgIn_i      (prog_data),

        .DataAddress_o (data_addr),
        .DataOut_o     (data_out),
        .DataIn_i      (data_in),
        .we_o          (data_we)
    );

    // No usamos RAM → devolvemos 0
    assign data_in = 32'b0;

    // Monitor
    initial begin
        $display("TIME | PC        | INSTR");
        forever begin
            @(posedge clk);
            if (!rst) begin
                $display("%4t | %h | %h",
                         $time, prog_addr, prog_data);
            end
        end
    end

    // Stop
    initial begin
        #2000;
        $finish;
    end

endmodule
