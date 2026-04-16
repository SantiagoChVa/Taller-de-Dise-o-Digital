module top (
    input  logic        clk_i,
    input  logic        rst_i,
    
    // UART
    output logic        uart_tx_o,
    input  logic        uart_rx_i,
    
    // Switches y LEDs
    input  logic [15:0] sw_i,
    output logic [15:0] leds_o
);

    // Señales internas
    logic clk_10mhz;
    logic pll_locked;
    logic rst_clean;

    // PLL - 10 MHz
    pll pll_inst (
        .clk_in1  (clk_i),
        .reset    (1'b0),
        .clk_out1 (clk_10mhz),
        .locked   (pll_locked)
    );

    // Reset sincronizado y extendido
    logic [2:0] rst_sync_ff;
    logic rst_btn_sync;
    logic [7:0] rst_cnt;

    always_ff @(posedge clk_10mhz) begin
        rst_sync_ff <= {rst_sync_ff[1:0], rst_i};
    end

    assign rst_btn_sync = rst_sync_ff[2];

    always_ff @(posedge clk_10mhz) begin
        if (rst_btn_sync || !pll_locked) begin
            rst_cnt <= 8'd0;
        end else if (rst_cnt != 8'hFF) begin
            rst_cnt <= rst_cnt + 1;
        end
    end

    assign rst_clean = (rst_cnt != 8'hFF);

    // PicoRV32
    logic        mem_valid;
    logic        mem_instr;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wstrb;
    logic [31:0] mem_rdata;
    logic        mem_ready;
    logic        trace_valid;
    logic [35:0] trace_data;

    picorv32 #(
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0),
        .ENABLE_TRACE(0),
        .TWO_STAGE_SHIFT(1),
        .BARREL_SHIFTER(1),
        .TWO_CYCLE_COMPARE(1),
        .TWO_CYCLE_ALU(1),
        .COMPRESSED_ISA(0),
        .CATCH_MISALIGN(1),
        .CATCH_ILLINSN(1),
        .ENABLE_PCPI(0),
        .ENABLE_COUNTERS(1),
        .ENABLE_COUNTERS64(0),
        .ENABLE_FAST_MUL(0),
        .ENABLE_IRQ_QREGS(0),
        .ENABLE_IRQ_TIMER(0),
        .MASKED_IRQ(0),
        .LATCHED_MEM_RDATA(0),
        .PROGADDR_RESET(32'h0000_0000),
        .PROGADDR_IRQ(32'h0000_0010),
        .STACKADDR(32'hFFFF_FFFF)
    ) u_cpu (
        .clk         (clk_10mhz),
        .resetn      (~rst_clean),
        .mem_valid   (mem_valid),
        .mem_instr   (mem_instr),
        .mem_ready   (mem_ready),
        .mem_addr    (mem_addr),
        .mem_wdata   (mem_wdata),
        .mem_wstrb   (mem_wstrb),
        .mem_rdata   (mem_rdata),
        .irq         (32'h0),
        .eoi         (),
        .trace_valid (trace_valid),
        .trace_data  (trace_data)
    );

    // Memorias
    logic [8:0]  rom_addr;
    logic [31:0] rom_rdata;
    logic        rom_rsta_busy;

    logic [14:0] ram_addr;
    logic [31:0] ram_wdata;
    logic [31:0] ram_rdata;
    logic        ram_we;

    rom_programa rom_inst (
        .clka      (clk_10mhz),
        .rsta      (rst_clean),
        .addra     (rom_addr),
        .douta     (rom_rdata),
        .rsta_busy (rom_rsta_busy)
    );

    ram_datos ram_inst (
        .clka  (clk_10mhz),
        .wea   (ram_we),
        .addra (ram_addr),
        .dina  (ram_wdata),
        .douta (ram_rdata)
    );

    // UART
    logic        uart_tx_dv;
    logic [7:0]  uart_tx_byte;
    logic        uart_tx_active;
    logic        uart_tx_done;

    logic        uart_rx_dv;
    logic [7:0]  uart_rx_byte;
    logic        uart_rx_ack;

    localparam int CLKS_PER_BIT = 87;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx_inst (
        .i_Clock     (clk_10mhz),
        .i_Tx_DV     (uart_tx_dv),
        .i_Tx_Byte   (uart_tx_byte),
        .o_Tx_Active (uart_tx_active),
        .o_Tx_Serial (uart_tx_o),
        .o_Tx_Done   (uart_tx_done)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_rx_inst (
        .i_Clock     (clk_10mhz),
        .i_Rx_Serial (uart_rx_i),
        .o_Rx_DV     (uart_rx_dv),
        .o_Rx_Byte   (uart_rx_byte)
    );

    // Bus Driver
    bus_driver bus_driver_inst (
        .clk_i          (clk_10mhz),
        .rst_i          (rst_clean),
        .mem_valid_i    (mem_valid),
        .mem_instr_i    (mem_instr),
        .mem_addr_i     (mem_addr),
        .mem_wdata_i    (mem_wdata),
        .mem_wstrb_i    (mem_wstrb),
        .mem_rdata_o    (mem_rdata),
        .mem_ready_o    (mem_ready),
        .rom_addr_o     (rom_addr),
        .rom_rdata_i    (rom_rdata),
        .ram_we_o       (ram_we),
        .ram_addr_o     (ram_addr),
        .ram_wdata_o    (ram_wdata),
        .ram_rdata_i    (ram_rdata),
        .switches_i     (sw_i),
        .leds_o         (leds_o),
        .uart_tx_dv_o   (uart_tx_dv),
        .uart_tx_byte_o (uart_tx_byte),
        .uart_tx_active_i(uart_tx_active),
        .uart_tx_done_i (uart_tx_done),
        .uart_rx_dv_i   (uart_rx_dv),
        .uart_rx_byte_i (uart_rx_byte),
        .uart_rx_ack_o  (uart_rx_ack),
        .rom_busy_i     (rom_rsta_busy)
    );

endmodule
