`timescale 1ns/1ps

module tb_bus_driver;

    logic clk;
    logic rst;

    // CPU signals
    logic        mem_valid;
    logic        mem_instr;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;
    logic        mem_ready;

    // ROM
    logic [8:0]  rom_addr;
    logic [31:0] rom_rdata;
    logic        rom_busy;

    // RAM
    logic        ram_we;
    logic [14:0] ram_addr;
    logic [31:0] ram_wdata;
    logic [31:0] ram_rdata;

    // IO
    logic [15:0] switches;
    logic [15:0] leds;

    // UART
    logic uart_tx_dv;
    logic [7:0] uart_tx_byte;
    logic uart_tx_active;
    logic uart_tx_done;
    logic uart_rx_dv;
    logic [7:0] uart_rx_byte;
    logic uart_rx_ack;

    // DUT
    bus_driver dut (
        .clk_i(clk),
        .rst_i(rst),

        .mem_valid_i(mem_valid),
        .mem_instr_i(mem_instr),
        .mem_addr_i(mem_addr),
        .mem_wdata_i(mem_wdata),
        .mem_wstrb_i(mem_wstrb),
        .mem_rdata_o(mem_rdata),
        .mem_ready_o(mem_ready),

        .rom_addr_o(rom_addr),
        .rom_rdata_i(rom_rdata),
        .rom_busy_i(rom_busy),

        .ram_we_o(ram_we),
        .ram_addr_o(ram_addr),
        .ram_wdata_o(ram_wdata),
        .ram_rdata_i(ram_rdata),

        .switches_i(switches),
        .leds_o(leds),

        .uart_tx_dv_o(uart_tx_dv),
        .uart_tx_byte_o(uart_tx_byte),
        .uart_tx_active_i(uart_tx_active),
        .uart_tx_done_i(uart_tx_done),

        .uart_rx_dv_i(uart_rx_dv),
        .uart_rx_byte_i(uart_rx_byte),
        .uart_rx_ack_o(uart_rx_ack)
    );

    // Clock
    always #5 clk = ~clk;

    // Modelos simples
    assign rom_rdata = 32'hDEADBEEF;
    assign rom_busy  = 1'b0;

    always_ff @(posedge clk) begin
        if (ram_we)
            ram_rdata <= ram_wdata;
    end

    // Tarea de escritura con handshake
    task write_transaction(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        mem_addr  = addr;
        mem_wdata = data;
        mem_wstrb = 4'b1111;
        mem_valid = 1;
        mem_instr = 0;

        wait(mem_ready == 1);
        @(posedge clk);

        mem_valid = 0;
        mem_wstrb = 0;

        @(posedge clk);  // separación
    end
    endtask

    // Tarea de lectura con handshake
    task read_transaction(input [31:0] addr);
    begin
        @(posedge clk);
        mem_addr  = addr;
        mem_wstrb = 0;
        mem_valid = 1;
        mem_instr = 0;

        wait(mem_ready == 1);
        @(posedge clk);

        mem_valid = 0;

        @(posedge clk);  // separación
    end
    endtask

    // Test principal
    initial begin
        // Inicialización
        clk = 0;
        rst = 1;

        mem_valid = 0;
        mem_instr = 0;
        mem_addr  = 0;
        mem_wdata = 0;
        mem_wstrb = 0;

        switches = 0;

        uart_tx_active = 0;
        uart_tx_done   = 0;
        uart_rx_dv     = 0;
        uart_rx_byte   = 0;

        #20;
        rst = 0;

        // TEST 1: LEDs
        write_transaction(32'h00002004, 32'h0000AAAA);
        @(posedge clk);

        if (leds == 16'hAAAA)
            $display("[LED TEST] PASS");
        else
            $display("[LED TEST] FAIL - valor=%h", leds);

        // TEST 2: Switches
        switches = 16'h55AA;
        read_transaction(32'h00002000);

        if (mem_rdata == 32'h000055AA)
            $display("[SW TEST] PASS");
        else
            $display("[SW TEST] FAIL - valor=%h", mem_rdata);

        // TEST 3: RAM
        write_transaction(32'h00040000, 32'h12345678);
        $display("[RAM TEST] COMPLETADO");

        #50;
        $finish;
    end

endmodule
