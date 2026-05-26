// =============================================================================
// top.sv  — MODIFICADO: agrega señales SPI para ADXL362 (Nexys4 DDR)
//
// Pines SPI del ADXL362 en Nexys4 DDR (XDC):
//   ACL_MOSI   → JA[1]  o pin dedicado según constraints del board
//   ACL_MISO   → JA[2]
//   ACL_SCLK   → JA[3]
//   ACL_CSN    → JA[4]  (activo bajo)
// Verificar con el XDC de la Nexys4 DDR; en muchas versiones son:
//   set_property PACKAGE_PIN D3  [get_ports acl_mosi_o]  ; # ACL_MOSI
//   set_property PACKAGE_PIN D4  [get_ports acl_miso_i]  ; # ACL_MISO
//   set_property PACKAGE_PIN F4  [get_ports acl_sck_o]   ; # ACL_SCLK
//   set_property PACKAGE_PIN F3  [get_ports acl_cs_n_o]  ; # ACL_CSN
// =============================================================================
module top (
    input  logic        clk_in1,
    input  logic        rst_ext_i,   // CPU RESET activo bajo

    input  logic [15:0] sw_i,
    output logic [15:0] led_o,

    output logic        uart_tx_o,
    input  logic        uart_rx_i,

    // SPI — ADXL362
    output logic        acl_sck_o,
    output logic        acl_mosi_o,
    input  logic        acl_miso_i,
    output logic        acl_cs_n_o
);

    // ------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------
    logic rst_btn;
    assign rst_btn = ~rst_ext_i;

    // ------------------------------------------------------------------
    // PLL
    // ------------------------------------------------------------------
    logic clk_sys, pll_locked;
    pll u_pll (
        .clk_out1(clk_sys),
        .reset   (rst_btn),
        .locked  (pll_locked),
        .clk_in1 (clk_in1)
    );

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
    // ROM
    // ------------------------------------------------------------------
    logic rom_rsta_busy;
    rom_programa u_rom (
        .clka     (clk_sys),
        .rsta     (rst_sys),
        .addra    (prog_addr[10:2]),
        .douta    (prog_data),
        .rsta_busy(rom_rsta_busy)
    );

    // ------------------------------------------------------------------
    // RAM
    // ------------------------------------------------------------------
    logic [14:0] ram_addr;
    logic [31:0] ram_wdata, ram_rdata;
    logic [ 0:0] ram_we;

    ram_datos u_ram (
        .clka (clk_sys),
        .wea  (ram_we),
        .addra(ram_addr),
        .dina (ram_wdata),
        .douta(ram_rdata)
    );

    // ------------------------------------------------------------------
    // Bus Driver
    // ------------------------------------------------------------------
    logic [31:0] periph_addr, periph_wdata, periph_rdata;
    logic        periph_we;

    bus_driver u_bus (
        .clk_i         (clk_sys),
        .rst_i         (rst_sys),
        .DataAddress_i (data_addr),
        .DataOut_i     (data_out),
        .we_i          (data_we),
        .ram_addr_o    (ram_addr),
        .ram_wdata_o   (ram_wdata),
        .ram_we_o      (ram_we),
        .ram_rdata_i   (ram_rdata),
        .periph_addr_o (periph_addr),
        .periph_wdata_o(periph_wdata),
        .periph_we_o   (periph_we),
        .periph_rdata_i(periph_rdata),
        .DataIn_o      (data_in)
    );

    // ------------------------------------------------------------------
    // Periféricos unificados (incluye SPI)
    // CLKS_PER_BIT = 10 MHz / 115200  ≈ 87
    // SPI_CLK_DIV  = 4 → SCK = 10 MHz / 8 = 1.25 MHz (< 8 MHz máx ADXL362)
    // ------------------------------------------------------------------
    periph_hub #(
        .DEBOUNCE_CYCLES(50_000),
        .CLKS_PER_BIT   (87),
        .SPI_CLK_DIV    (4)
    ) u_periph (
        .clk_i     (clk_sys),
        .rst_i     (rst_sys),
        .addr_i    (periph_addr),
        .wdata_i   (periph_wdata),
        .we_i      (periph_we),
        .rdata_o   (periph_rdata),
        .sw_i      (sw_i),
        .led_o     (led_o),
        .uart_tx_o (uart_tx_o),
        .uart_rx_i (uart_rx_i),
        .spi_sck_o (acl_sck_o),
        .spi_mosi_o(acl_mosi_o),
        .spi_miso_i(acl_miso_i),
        .spi_cs_n_o(acl_cs_n_o)
    );

endmodule
