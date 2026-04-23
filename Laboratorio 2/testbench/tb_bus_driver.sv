// tb_bus_driver.sv - Testbench para bus_driver con latencia 1 ciclo
`timescale 1ns/1ps

module tb_bus_driver;

    localparam CLK_PERIOD = 10;

    logic        clk_i         = 0;
    logic        rst_i         = 1;
    logic [31:0] DataAddress_i = '0;
    logic [31:0] DataOut_i     = '0;
    logic        we_i          = 0;

    logic [14:0] ram_addr_o;
    logic [31:0] ram_wdata_o;
    logic [ 0:0] ram_we_o;
    logic [31:0] ram_rdata_i   = '0;

    logic [31:0] periph_addr_o;
    logic [31:0] periph_wdata_o;
    logic        periph_we_o;

    // Modelo de periph_hub: responde combinacionalmente a periph_addr_o
    logic [31:0] led_reg = '0;
    logic [31:0] periph_rdata_i;

    always_ff @(posedge clk_i) begin
        if (periph_we_o && periph_addr_o == 32'h02004)
            led_reg <= periph_wdata_o;
    end

    always_comb begin
        case (periph_addr_o)
            32'h02000: periph_rdata_i = 32'hCAFE_1234; // switches fijos
            32'h02004: periph_rdata_i = led_reg;
            default:   periph_rdata_i = 32'h0;
        endcase
    end

    logic [31:0] DataIn_o;

    bus_driver u_dut (.*);

    // Modelo RAM: latencia 1 ciclo
    // Ciclo 0: addr/we/wdata llegan al IP (combinacional desde bus_driver)
    // Ciclo 1: escritura ocurre en flanco, douta válido
    logic [31:0] ram_mem [0:32767];

    always_ff @(posedge clk_i) begin
        if (ram_we_o) begin
            ram_mem[ram_addr_o] <= ram_wdata_o;
        end
        ram_rdata_i <= ram_mem[ram_addr_o];
    end

    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // Tarea de escritura (1 ciclo de presentación)
    task automatic write32(input logic [31:0] addr, input logic [31:0] data);
        @(negedge clk_i);
        DataAddress_i = addr;
        DataOut_i     = data;
        we_i          = 1;
        @(negedge clk_i);
        we_i          = 0;
        DataAddress_i = '0;
        DataOut_i     = '0;
    endtask

    // Tarea de lectura (latencia 1 ciclo)
    // Presentar addr, esperar 1 ciclo, dato válido en DataIn_o
    task automatic read32(input logic [31:0] addr, output logic [31:0] data);
        @(negedge clk_i);
        DataAddress_i = addr;
        we_i          = 0;
        @(posedge clk_i);      // ciclo 1 - dato válido
        @(negedge clk_i);      // muestrear en flanco negativo (estable)
        data          = DataIn_o;
        DataAddress_i = '0;
    endtask

    logic [31:0] rd;

    initial begin
        $display("=== TB bus_driver START (Latencia 1 ciclo) ===");
        rst_i = 1;
        repeat(5) @(posedge clk_i);
        rst_i = 0;
        repeat(2) @(posedge clk_i);

        // Test 1: Escritura RAM @ 0x40010 (word addr = 4)
        $display("[%0t] TEST 1: Escritura RAM @ 0x40010", $time);
        write32(32'h40010, 32'h1234_5678);
        repeat(2) @(posedge clk_i);  // esperar que escritura complete

        // Test 2: Lectura RAM @ 0x40010
        $display("[%0t] TEST 2: Lectura RAM @ 0x40010", $time);
        read32(32'h40010, rd);
        if (rd == 32'h1234_5678)
            $display("  PASS: 0x%08h", rd);
        else
            $display("  FAIL: 0x%08h (esperado 0x12345678)", rd);

        // Test 3: Escritura periférico LED @ 0x02004
        $display("[%0t] TEST 3: Escritura periph LED @ 0x02004", $time);
        write32(32'h02004, 32'h0000_00AA);
        repeat(2) @(posedge clk_i);
        if (led_reg == 32'h0000_00AA)
            $display("  PASS: led_reg=0x%08h", led_reg);
        else
            $display("  FAIL: led_reg=0x%08h (esperado 0xAA)", led_reg);

        // Test 4: Lectura periférico switches @ 0x02000
        $display("[%0t] TEST 4: Lectura periph SW @ 0x02000", $time);
        read32(32'h02000, rd);
        if (rd == 32'hCAFE_1234)
            $display("  PASS: 0x%08h", rd);
        else
            $display("  FAIL: 0x%08h (esperado 0xCAFE1234)", rd);

        // Test 5: Segunda escritura RAM (dirección diferente)
        $display("[%0t] TEST 5: Escritura RAM @ 0x40020", $time);
        write32(32'h40020, 32'hDEAD_BEEF);
        repeat(2) @(posedge clk_i);
        read32(32'h40020, rd);
        if (rd == 32'hDEAD_BEEF)
            $display("  PASS: 0x%08h", rd);
        else
            $display("  FAIL: 0x%08h (esperado 0xDEADBEEF)", rd);

        // Test 6: Lectura consecutiva (verificar que no hay latencia extra)
        $display("[%0t] TEST 6: Lectura consecutiva RAM @ 0x40010", $time);
        read32(32'h40010, rd);
        $display("  Primera lectura: 0x%08h", rd);
        read32(32'h40010, rd);
        $display("  Segunda lectura: 0x%08h", rd);

        $display("=== TB bus_driver END ===");
        $finish;
    end

    initial begin
        #500_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
