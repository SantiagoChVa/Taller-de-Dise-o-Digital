// =============================================================================
// periph_hub.sv  - MODIFICADO: auto-start SPI al escribir en SPI_TX
//
// Mapa de memoria COMPLETO:
//   0x02000  SW/BTN        R
//   0x02004  LEDs          W
//   0x02010  UART_CTRL     R  [0]=tx_busy [1]=rx_ready
//   0x02018  UART_TX       W  / lectura del último byte enviado
//   0x0201C  UART_RX       R
//   0x02020  SPI_CTRL      RW [0]=start [1]=busy(ro) [7:4]=cmd
//   0x02028  SPI_TX/RX     RW [31:16]=addr [7:0]=data (write) / rx_byte (read)
//   0x0202C  SPI_DATA      R  [15:0]={byte_hi, byte_lo}
//
// MEJORA: Escribir en SPI_TX (0x02028) también inicia automáticamente
//         la transacción SPI si el SPI está idle. No es necesario escribir
//         en SPI_CTRL a menos que se quiera cambiar el comando (READ/RFIFO).
// =============================================================================
module periph_hub #(
    parameter int DEBOUNCE_CYCLES = 50_000,
    parameter int CLKS_PER_BIT    = 87,
    parameter int SPI_CLK_DIV     = 4
)(
    input  logic        clk_i,
    input  logic        rst_i,

    // --- Interfaz con el bus driver ---
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    output logic [31:0] rdata_o,

    // --- E/S físicas ---
    input  logic [15:0] sw_i,
    output logic [15:0] led_o,
    output logic        uart_tx_o,
    input  logic        uart_rx_i,

    // --- SPI ---
    output logic        spi_sck_o,
    output logic        spi_mosi_o,
    input  logic        spi_miso_i,
    output logic        spi_cs_n_o
);

    // =========================================================================
    // 1. SWITCHES con anti-rebote
    // =========================================================================
    logic [15:0] sw_sync1, sw_sync2;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin sw_sync1 <= '0; sw_sync2 <= '0; end
        else begin sw_sync1 <= sw_i; sw_sync2 <= sw_sync1; end
    end

    logic [15:0] sw_stable, sw_last;
    logic [$clog2(DEBOUNCE_CYCLES+1)-1:0] deb_cnt;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin sw_stable <= '0; sw_last <= '0; deb_cnt <= '0; end
        else begin
            if (sw_sync2 != sw_last) begin sw_last <= sw_sync2; deb_cnt <= '0; end
            else if (deb_cnt < DEBOUNCE_CYCLES) deb_cnt <= deb_cnt + 1;
            else sw_stable <= sw_last;
        end
    end

    // =========================================================================
    // 2. LEDs
    // =========================================================================
    logic [31:0] led_reg;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) led_reg <= '0;
        else if (we_i && addr_i == 32'h02004) led_reg <= wdata_i;
    end
    assign led_o = led_reg[15:0];

    // =========================================================================
    // 3. UART
    // =========================================================================
    logic [7:0] uart_tx_data, uart_rx_data;
    logic       tx_busy, rx_data_ready;
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active, tx_done;
    logic       rx_dv;
    logic [7:0] rx_byte;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock    (clk_i), .i_Tx_DV(tx_dv), .i_Tx_Byte(tx_byte),
        .o_Tx_Active(tx_active), .o_Tx_Serial(uart_tx_o), .o_Tx_Done(tx_done)
    );
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock    (clk_i), .i_Rx_Serial(uart_rx_i),
        .o_Rx_DV    (rx_dv), .o_Rx_Byte(rx_byte)
    );

    logic [7:0] tx_pending_data;
    logic       tx_pending;
    logic       reading_rx;
    assign reading_rx = (addr_i == 32'h0201C) && !we_i;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_tx_data <= '0; uart_rx_data <= '0;
            tx_busy <= 1'b0; rx_data_ready <= 1'b0;
            tx_dv <= 1'b0; tx_byte <= '0;
            tx_pending <= 1'b0; tx_pending_data <= '0;
        end else begin
            if (we_i && addr_i == 32'h02018) begin
                uart_tx_data <= wdata_i[7:0];
                if (!tx_active && !tx_pending) begin
                    tx_byte <= wdata_i[7:0]; tx_dv <= 1'b1;
                end else begin
                    tx_pending_data <= wdata_i[7:0]; tx_pending <= 1'b1;
                end
            end else tx_dv <= 1'b0;

            if (tx_done && tx_pending) begin
                tx_byte <= tx_pending_data; tx_dv <= 1'b1; tx_pending <= 1'b0;
            end
            tx_busy <= tx_active || tx_pending;

            if (rx_dv) begin uart_rx_data <= rx_byte; rx_data_ready <= 1'b1; end
            else if (reading_rx) rx_data_ready <= 1'b0;
        end
    end

    // =========================================================================
    // 4. SPI con AUTO-START al escribir en SPI_TX
    // =========================================================================
    logic [31:0] spi_ctrl_reg;   // 0x02020
    logic [31:0] spi_tx_reg;     // 0x02028 (write: [15:8]=addr, [7:0]=data)
    logic [31:0] spi_rx_reg;     // 0x02028 (read)
    logic [31:0] spi_data_reg;   // 0x0202C (read)
    logic        spi_busy;
    
    // Señales para auto-start
    logic        spi_tx_written;      // Se escribió en SPI_TX en este ciclo
    logic        start_auto;          // Start generado por auto-start
    logic        start_explicit;      // Start explícito por SPI_CTRL
    logic [31:0] effective_ctrl;      // Control efectivo para spi_master
    
    // Escritura de registros SPI
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            spi_ctrl_reg <= '0;
            spi_tx_reg   <= '0;
            spi_tx_written <= 1'b0;
        end else begin
            // Detectar escritura en SPI_TX (señal de un ciclo)
            if (we_i && addr_i == 32'h02028) begin
                spi_tx_reg <= wdata_i;
                spi_tx_written <= 1'b1;
            end else begin
                spi_tx_written <= 1'b0;
            end
            
            // Escritura normal en SPI_CTRL (si se escribe, se sobreescribe)
            if (we_i && addr_i == 32'h02020) begin
                spi_ctrl_reg <= wdata_i;
            end
            
            // Auto-clear del bit start después de un ciclo
            // (tanto para start explícito como auto-start)
            if (start_explicit || start_auto) begin
                spi_ctrl_reg[0] <= 1'b0;
            end
        end
    end
    
    // Detección de start explícito por SPI_CTRL
    // (flanco ascendente del bit 0 de spi_ctrl_reg)
    logic spi_ctrl_start_prev;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) spi_ctrl_start_prev <= 1'b0;
        else spi_ctrl_start_prev <= spi_ctrl_reg[0];
    end
    assign start_explicit = spi_ctrl_reg[0] && !spi_ctrl_start_prev;
    
    // Start automático al escribir en SPI_TX (solo si SPI está idle)
    assign start_auto = spi_tx_written && !spi_busy;
    
    // Señal de start combinada (prioridad: auto-start > explícito)
    // Nota: si ambos ocurren en el mismo ciclo, auto-start tiene preferencia
    wire start_combined = start_auto || start_explicit;
    
    // Control efectivo para el spi_master:
    // - Si es auto-start, usamos cmd por defecto = WRITE (0)
    // - Si es start explícito, usamos el cmd de spi_ctrl_reg
    // - También propagamos el bit start (siempre 1 cuando start_combined)
    assign effective_ctrl = start_auto ? 
                            {spi_ctrl_reg[31:4], 4'b0000, 1'b0, 1'b1} :  // auto-start: cmd=WRITE, start=1
                            {spi_ctrl_reg[31:1], 1'b1};                     // start explícito: usar cmd existente
    
    // Instancia del maestro SPI (conectado al control efectivo)
    spi_master #(.CLK_DIV(SPI_CLK_DIV)) u_spi (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .ctrl_reg_i (effective_ctrl),   // Usamos control efectivo
        .tx_reg_i   (spi_tx_reg),
        .rx_reg_o   (spi_rx_reg),
        .data_reg_o (spi_data_reg),
        .busy_o     (spi_busy),
        .spi_sck_o  (spi_sck_o),
        .spi_mosi_o (spi_mosi_o),
        .spi_miso_i (spi_miso_i),
        .spi_cs_n_o (spi_cs_n_o)
    );

    // =========================================================================
    // 5. Multiplexor de lectura
    // =========================================================================
    always_comb begin
        case (addr_i)
            32'h02000: rdata_o = {16'b0, sw_stable};
            32'h02004: rdata_o = led_reg;
            32'h02010: rdata_o = {30'b0, rx_data_ready, tx_busy};
            32'h02018: rdata_o = {24'b0, uart_tx_data};
            32'h0201C: rdata_o = {24'b0, uart_rx_data};
            32'h02020: rdata_o = {spi_ctrl_reg[31:2], spi_busy, spi_ctrl_reg[0]};
            32'h02028: rdata_o = spi_rx_reg;
            32'h0202C: rdata_o = spi_data_reg;
            default:   rdata_o = 32'b0;
        endcase
    end

endmodule
