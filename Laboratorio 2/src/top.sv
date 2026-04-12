module top (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        uart_rx_i,
    output logic        uart_tx_o,
    output logic [15:0] leds_o,
    input  logic [15:0] sw_i
);

// señales internas
logic        clk;

// bus PicoRV32 <-> Bus Driver
logic        mem_valid;
logic        mem_instr;
logic        mem_ready;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [ 3:0] mem_wstrb;
logic [31:0] mem_rdata;

// ROM y RAM
logic [ 8:0] rom_addr;
logic [31:0] rom_data;
logic [14:0] ram_addr;
logic [31:0] ram_wdata;
logic [ 3:0] ram_we;
logic [31:0] ram_rdata;

// UART — señales entre Bus Driver y los módulos TX/RX
logic        uart_tx_dv;       // Bus Driver le dice al TX "mandá este byte"
logic        uart_tx_active;   // TX ocupado
logic        uart_tx_done;     // TX terminó
logic [ 7:0] uart_tx_byte;     // byte a transmitir
logic        uart_rx_dv;       // RX recibió un byte
logic [ 7:0] uart_rx_byte;     // byte recibido

// ── instancias ────────────────────────────────────────────────

pll u_pll (
    .clk_in  (clk_i),
    .clk_out (clk)
);

picorv32 #(
    .COMPRESSED_ISA (0),
    .ENABLE_MUL     (0),
    .ENABLE_DIV     (0),
    .STACKADDR      (32'h0007_FFFC)
) u_cpu (
    .clk       (clk),
    .resetn    (~rst_i),
    .mem_valid (mem_valid),
    .mem_instr (mem_instr),
    .mem_ready (mem_ready),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_rdata (mem_rdata)
);

rom_programa u_rom (
    .clka  (clk),
    .addra (rom_addr),
    .douta (rom_data)
);

ram_datos u_ram (
    .clka  (clk),
    .addra (ram_addr),
    .dina  (ram_wdata),
    .douta (ram_rdata),
    .wea   (ram_we)
);

bus_driver u_bus (
    .clk_i         (clk),
    .rst_i         (rst_i),
    .mem_valid     (mem_valid),
    .mem_addr      (mem_addr),
    .mem_wdata     (mem_wdata),
    .mem_wstrb     (mem_wstrb),
    .mem_ready     (mem_ready),
    .mem_rdata     (mem_rdata),
    .rom_addr      (rom_addr),
    .rom_data      (rom_data),
    .ram_addr      (ram_addr),
    .ram_wdata     (ram_wdata),
    .ram_we        (ram_we),
    .ram_rdata     (ram_rdata),
    .led_reg       (leds_o),
    .sw_reg        (sw_i),
    // UART
    .uart_tx_dv    (uart_tx_dv),
    .uart_tx_active(uart_tx_active),
    .uart_tx_done  (uart_tx_done),
    .uart_tx_byte  (uart_tx_byte),
    .uart_rx_dv    (uart_rx_dv),
    .uart_rx_byte  (uart_rx_byte)
);

uart_tx #(
    .CLKS_PER_BIT (87)   // ajustá según tu frecuencia de PLL
) u_uart_tx (
    .i_Clock     (clk),
    .i_Tx_DV     (uart_tx_dv),
    .i_Tx_Byte   (uart_tx_byte),
    .o_Tx_Active (uart_tx_active),
    .o_Tx_Serial (uart_tx_o),
    .o_Tx_Done   (uart_tx_done)
);

uart_rx #(
    .CLKS_PER_BIT (87)   // ajustá según tu frecuencia de PLL
) u_uart_rx (
    .i_Clock     (clk),
    .i_Rx_Serial (uart_rx_i),
    .o_Rx_DV     (uart_rx_dv),
    .o_Rx_Byte   (uart_rx_byte)
);

endmodule
