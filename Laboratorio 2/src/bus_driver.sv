module bus_driver (
    input  logic        clk_i,
    input  logic        rst_i,
    
    // CPU
    input  logic        mem_valid_i,
    input  logic        mem_instr_i,
    input  logic [31:0] mem_addr_i,
    input  logic [31:0] mem_wdata_i,
    input  logic [3:0]  mem_wstrb_i,
    output logic [31:0] mem_rdata_o,
    output logic        mem_ready_o,
    
    // ROM
    output logic [8:0]  rom_addr_o,
    input  logic [31:0] rom_rdata_i,
    input  logic        rom_busy_i,
    
    // RAM
    output logic        ram_we_o,
    output logic [14:0] ram_addr_o,
    output logic [31:0] ram_wdata_o,
    input  logic [31:0] ram_rdata_i,
    
    // IO
    input  logic [15:0] switches_i,
    output logic [15:0] leds_o,
    
    // UART
    output logic        uart_tx_dv_o,
    output logic [7:0]  uart_tx_byte_o,
    input  logic        uart_tx_active_i,
    input  logic        uart_tx_done_i,
    
    input  logic        uart_rx_dv_i,
    input  logic [7:0]  uart_rx_byte_i,
    output logic        uart_rx_ack_o
);

    //=========================================================================
    // REGISTROS DE TRANSACCIÓN (capturan al inicio del handshake)
    //=========================================================================
    logic [31:0] addr_reg;
    logic [31:0] wdata_reg;
    logic [3:0]  wstrb_reg;
    logic        instr_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            addr_reg  <= 0;
            wdata_reg <= 0;
            wstrb_reg <= 0;
            instr_reg <= 0;
        end else begin
            // Capturar cuando llega una nueva transacción válida
            if (mem_valid_i && !mem_ready_o) begin
                addr_reg  <= mem_addr_i;
                wdata_reg <= mem_wdata_i;
                wstrb_reg <= mem_wstrb_i;
                instr_reg <= mem_instr_i;
            end
        end
    end

    //=========================================================================
    // READY (latencia de 1 ciclo)
    //=========================================================================
    logic valid_d;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            valid_d     <= 0;
            mem_ready_o <= 0;
        end else begin
            valid_d     <= mem_valid_i;
            mem_ready_o <= valid_d;
        end
    end

    //=========================================================================
    // DECODIFICACIÓN DE DIRECCIONES
    //=========================================================================
    logic rom_sel, ram_sel, io_sel;

    always_comb begin
        rom_sel = instr_reg;

        ram_sel = (addr_reg[31:16] == 16'h0004 ||
                   addr_reg[31:16] == 16'h0005 ||
                   addr_reg[31:16] == 16'h0006 ||
                   addr_reg[31:16] == 16'h0007);

        io_sel  = !rom_sel && !ram_sel;
    end

    assign rom_addr_o = addr_reg[10:2];
    assign ram_addr_o = addr_reg[16:2];
    assign ram_we_o   = ram_sel && |wstrb_reg;
    assign ram_wdata_o = wdata_reg;

    //=========================================================================
    // LECTURA COMBINACIONAL
    //=========================================================================
    always_comb begin
        mem_rdata_o = 32'h0;

        if (rom_sel) begin
            mem_rdata_o = rom_rdata_i;
        end else if (ram_sel) begin
            mem_rdata_o = ram_rdata_i;
        end else begin
            case (addr_reg)
                32'h00002000: mem_rdata_o = {16'h0, switches_i};
                32'h00002004: mem_rdata_o = {16'h0, leds_o};
                default:      mem_rdata_o = 32'h0;
            endcase
        end
    end

    //=========================================================================
    // LEDS (escritura registrada)
    //=========================================================================
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            leds_o <= 16'h0;
        end else if (mem_ready_o && |wstrb_reg && addr_reg == 32'h00002004) begin
            leds_o <= wdata_reg[15:0];
        end
    end

    //=========================================================================
    // UART (versión final robusta)
    //=========================================================================
    logic [7:0] tx_reg;
    logic       uart_tx_dv_reg;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            tx_reg          <= 8'h00;
            uart_tx_dv_reg  <= 1'b0;
        end else begin
            uart_tx_dv_reg <= 1'b0;  // pulso de 1 ciclo

            // escritura del dato a transmitir
            if (mem_ready_o && |wstrb_reg && addr_reg == 32'h00002018) begin
                tx_reg <= wdata_reg[7:0];
            end

            // disparador de transmisión
            if (mem_ready_o && |wstrb_reg &&
                addr_reg == 32'h00002010 && wdata_reg[0]) begin
                uart_tx_dv_reg <= 1'b1;
            end
        end
    end

    assign uart_tx_byte_o = tx_reg;
    assign uart_tx_dv_o   = uart_tx_dv_reg;
    assign uart_rx_ack_o  = 1'b0;  // no implementado

endmodule
