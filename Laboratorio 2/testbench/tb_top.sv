`timescale 1ns/1ps

module tb_core_ram;

    // Señales
    logic clk;
    logic rst;

    // Core <-> sistema
    logic [31:0] prog_addr, prog_data;
    logic [31:0] data_addr, data_out, data_in;
    logic        data_we;

    // RAM
    logic [14:0] ram_addr;
    logic [31:0] ram_wdata, ram_rdata;
    logic [0:0]  ram_we;

    // Periféricos (no usados, pero necesarios)
    logic [31:0] periph_addr, periph_wdata, periph_rdata;
    logic        periph_we;

    // Clock
    always #5 clk = ~clk; // 100 MHz
    // DUTs
    // Core
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

    // ROM (programa .coe)
    rom_programa u_rom (
        .clka  (clk),
        .rsta  (rst),
        .addra (prog_addr[10:2]),
        .douta (prog_data)
    );

    // RAM
    ram_datos u_ram (
        .clka  (clk),
        .wea   (ram_we),
        .addra (ram_addr),
        .dina  (ram_wdata),
        .douta (ram_rdata)
    );

    // Bus driver
    bus_driver u_bus (
        .clk_i          (clk),
        .rst_i          (rst),
        .DataAddress_i  (data_addr),
        .DataOut_i      (data_out),
        .we_i           (data_we),

        .ram_addr_o     (ram_addr),
        .ram_wdata_o    (ram_wdata),
        .ram_we_o       (ram_we),
        .ram_rdata_i    (ram_rdata),

        .periph_addr_o  (periph_addr),
        .periph_wdata_o (periph_wdata),
        .periph_we_o    (periph_we),
        .periph_rdata_i (32'b0), // no usamos periféricos

        .DataIn_o       (data_in)
    );

    // Inicialización
    initial begin
        clk = 0;
        rst = 1;

        #50;
        rst = 0;

        // correr suficiente tiempo
        #200000;

        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (!rst) begin
            $display("T=%0t | PC=%h | ADDR=%h | WE=%b | WDATA=%h | RDATA=%h",
                     $time, prog_addr, data_addr, data_we, data_out, data_in);
        end
    end

endmodule
