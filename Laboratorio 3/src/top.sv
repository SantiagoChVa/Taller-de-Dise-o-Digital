// =============================================================================
// top.sv
// Módulo top del sistema embebido RISC-V en FPGA (Nexys4 DDR).
//
// NOTA DE RESET:
//   El botón CPU RESET de la Nexys4 DDR es ACTIVO BAJO (pin = 0 al presionar).
//   Internamente todo el sistema usa reset activo alto (rst_sys).
//   Se invierte rst_ext_i → rst_btn antes de usarlo.
//
// Jerarquía:
//   top
//   ├── pll               (IP Vivado)
//   ├── riscv_core_wrapper
//   ├── rom_programa       (IP Vivado)
//   ├── ram_datos          (IP Vivado)
//   ├── bus_driver
//   └── periph_hub
//       ├── uart_tx / uart_rx
//       └── spi_periph     ← NUEVO
//
// Pines SPI para el ADXL362 en Nexys4 DDR (XDC):
//   ACL_MOSI → JD[1] 
//   ACL_MISO → JD[2]  
//   ACL_SCLK → JD[3]
//   ACL_CSN  → JD[0]
// =============================================================================
module top (
    input  logic        clk_in1,   // 100 MHz de la FPGA
    input  logic        rst_ext_i, // CPU RESET Nexys4 DDR: activo BAJO

    input  logic [15:0] sw_i,
    output logic [15:0] led_o,

    output logic        uart_tx_o,
    input  logic        uart_rx_i,

    // --- SPI para ADXL362 ---
    output logic        acl_sck_o,   // ACL_SCLK en XDC Nexys4
    output logic        acl_mosi_o,  // ACL_MOSI
    input  logic        acl_miso_i,  // ACL_MISO
    output logic        acl_cs_n_o   // ACL_CSN
);

    // ------------------------------------------------------------------
    // Inversión de reset: el botón es activo bajo, todo lo demás activo alto
    // ------------------------------------------------------------------
    logic rst_btn;
    assign rst_btn = ~rst_ext_i;   // rst_btn = 1 cuando botón presionado

    // ------------------------------------------------------------------
    // PLL (Clocking Wizard espera reset activo alto)
    // ------------------------------------------------------------------
    logic clk_sys, pll_locked;

    pll u_pll (
        .clk_out1 (clk_sys),
        .reset    (rst_btn),
        .locked   (pll_locked),
        .clk_in1  (clk_in1)
    );

    // Reset del sistema: activo hasta que PLL esté estable
    logic rst_sys;
    always_ff @(posedge clk_sys or posedge rst_btn) begin
        if (rst_btn) rst_sys <= 1'b1;
        else         rst_sys <= ~pll_locked;
    end

    // ------------------------------------------------------------------
    // Núcleo RISC-V
    // ------------------------------------------------------------------
    logic [31:0] prog_addr, prog_data;
    logic [31:0] data_addr, data_out, data_in;
    logic        data_we;

    riscv_core_wrapper u_core (
        .clk_i         (clk_sys),
        .rst_i         (rst_sys),
        .ProgAddress_o (prog_addr),
        .ProgIn_i      (prog_data),
        .DataAddress_o (data_addr),
        .DataOut_o     (data_out),
        .DataIn_i      (data_in),
        .we_o          (data_we)
    );

    // ------------------------------------------------------------------
    // ROM (IP Vivado)
    // ------------------------------------------------------------------
    logic rom_rsta_busy;

    rom_programa u_rom (
        .clka      (clk_sys),
        .rsta      (rst_sys),
        .addra     (prog_addr[10:2]),
        .douta     (prog_data),
        .rsta_busy (rom_rsta_busy)
    );

    // ------------------------------------------------------------------
    // RAM (IP Vivado)
    // ------------------------------------------------------------------
    logic [14:0] ram_addr;
    logic [31:0] ram_wdata, ram_rdata;
    logic [ 0:0] ram_we;

    ram_datos u_ram (
        .clka  (clk_sys),
        .wea   (ram_we),
        .addra (ram_addr),
        .dina  (ram_wdata),
        .douta (ram_rdata)
    );

    // ------------------------------------------------------------------
    // Bus Driver
    // ------------------------------------------------------------------
    logic [31:0] periph_addr, periph_wdata, periph_rdata;
    logic        periph_we;

    bus_driver u_bus (
        .clk_i          (clk_sys),
        .rst_i          (rst_sys),
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
        .periph_rdata_i (periph_rdata),
        .DataIn_o       (data_in)
    );

    // ------------------------------------------------------------------
    // Periféricos unificados
    // CLKS_PER_BIT    = 10 MHz / 115200 ≈ 87
    // DEBOUNCE_CYCLES = 10 MHz × 5 ms   = 50 000
    // SPI_CLK_DIV     = 5  → SPI_CLK = 10 MHz / 10 = 1 MHz
    // ------------------------------------------------------------------
    periph_hub #(
        .DEBOUNCE_CYCLES(50_000),
        .CLKS_PER_BIT   (87),
        .SPI_CLK_DIV    (5)
    ) u_periph (
        .clk_i      (clk_sys),
        .rst_i      (rst_sys),
        .addr_i     (periph_addr),
        .wdata_i    (periph_wdata),
        .we_i       (periph_we),
        .rdata_o    (periph_rdata),
        .sw_i       (sw_i),
        .led_o      (led_o),
        .uart_tx_o  (uart_tx_o),
        .uart_rx_i  (uart_rx_i),
        // SPI → ADXL362
        .spi_sck_o  (acl_sck_o),
        .spi_mosi_o (acl_mosi_o),
        .spi_miso_i (acl_miso_i),
        .spi_cs_n_o (acl_cs_n_o)
    );

endmodule
