`timescale 1ns/1ps

module tb_uart_regs;

    logic clk;
    always #5 clk = ~clk;

    logic rst;

    logic mem_valid;
    logic mem_instr;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;
    logic mem_ready;

    logic uart_tx_dv;
    logic [7:0] uart_tx_byte;

    logic tx_detected;

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

        .rom_addr_o(),
        .rom_rdata_i(32'h0),
        .rom_busy_i(1'b0),

        .ram_we_o(),
        .ram_addr_o(),
        .ram_wdata_o(),
        .ram_rdata_i(32'h0),

        .switches_i(16'h0000),
        .leds_o(),

        .uart_tx_dv_o(uart_tx_dv),
        .uart_tx_byte_o(uart_tx_byte),
        .uart_tx_active_i(1'b0),
        .uart_tx_done_i(1'b0),

        .uart_rx_dv_i(1'b0),
        .uart_rx_byte_i(8'h00),
        .uart_rx_ack_o()
    );

    // Monitor UART (único driver)
    always_ff @(posedge clk) begin
        if (rst) begin
            tx_detected <= 0;
        end else if (uart_tx_dv) begin
            tx_detected <= 1;
            $display("[UART] TX ACTIVADO byte=%h", uart_tx_byte);
        end
    end

    // Tarea de escritura con handshake y separación
    task write_transaction(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk);

        mem_addr  <= addr;
        mem_wdata <= data;
        mem_wstrb <= 4'b1111;
        mem_valid <= 1;
        mem_instr <= 0;

        wait(mem_ready == 1);
        @(posedge clk);

        mem_valid <= 0;
        mem_wstrb <= 0;
        mem_addr  <= 0;
        mem_wdata <= 0;

        @(posedge clk);  // separación crítica
    end
    endtask

    // Test principal
    initial begin
        clk = 0;
        rst = 1;

        mem_valid = 0;
        mem_instr = 0;
        mem_addr  = 0;
        mem_wdata = 0;
        mem_wstrb = 0;

        #20;
        rst = 0;

        // Escribir dato en registro TX
        write_transaction(32'h00002018, 32'h00000041);

        // Disparar transmisión
        write_transaction(32'h00002010, 32'h00000001);

        repeat(5) @(posedge clk);

        if (tx_detected)
            $display("[UART TEST] PASS");
        else
            $display("[UART TEST] FAIL");

        #20;
        $finish;
    end

endmodule
