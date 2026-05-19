// =============================================================================
// periph_hub.sv
// Módulo unificado de periféricos del sistema RISC-V.
//
// Concentra en un solo bloque:
//   - Switches / Botones  (0x02000) — solo lectura, con anti-rebote
//   - LEDs                (0x02004) — solo escritura
//   - UART Control        (0x02010) — solo lectura (status)
//   - UART Data 0 (TX)    (0x02018) — solo escritura
//   - UART Data 1 (RX)    (0x0201C) — solo lectura
//   - SPI Control         (0x02020) — solo lectura (status)
//   - SPI Data TX         (0x02028) — escritura inicia transacción
//   - SPI Data RX         (0x0202C) — solo lectura, limpia RX_READY
//
// Comportamiento UART mejorado:
//   - Escribir en UART_TX inicia la transmisión automáticamente.
//   - Leer UART_RX devuelve el último byte recibido y limpia el flag new_rx.
//   - UART_CTRL: bit0 = TX_BUSY, bit1 = RX_DATA_READY.
//
// Comportamiento SPI:
//   - Escribir en SPI_TX (bit[7:0]=dato, bit[8]=CS_HOLD) arranca la transacción.
//   - SPI_CTRL: bit0 = SPI_BUSY, bit1 = RX_READY.
//   - Leer SPI_RX devuelve byte recibido y limpia RX_READY.
// =============================================================================
module periph_hub #(
    parameter int DEBOUNCE_CYCLES = 50_000,
    parameter int CLKS_PER_BIT    = 87,
    parameter int SPI_CLK_DIV     = 5     // SPI_CLK = clk_i / (2*SPI_CLK_DIV)
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

    // --- SPI (ADXL362 en Nexys4) ---
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
        if (rst_i) begin
            sw_sync1 <= '0;
            sw_sync2 <= '0;
        end else begin
            sw_sync1 <= sw_i;
            sw_sync2 <= sw_sync1;
        end
    end

    logic [15:0] sw_stable, sw_last;
    logic [$clog2(DEBOUNCE_CYCLES+1)-1:0] deb_cnt;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            sw_stable <= '0;
            sw_last   <= '0;
            deb_cnt   <= '0;
        end else begin
            if (sw_sync2 != sw_last) begin
                sw_last <= sw_sync2;
                deb_cnt <= '0;
            end else if (deb_cnt < DEBOUNCE_CYCLES) begin
                deb_cnt <= deb_cnt + 1;
            end else begin
                sw_stable <= sw_last;
            end
        end
    end

    // =========================================================================
    // 2. LEDs
    // =========================================================================
    logic [31:0] led_reg;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i)
            led_reg <= '0;
        else if (we_i && addr_i == 32'h02004)
            led_reg <= wdata_i;
    end
    assign led_o = led_reg[15:0];

    // =========================================================================
    // 3. UART
    // =========================================================================
    logic [7:0] uart_tx_data;
    logic [7:0] uart_rx_data;
    logic       tx_busy;
    logic       rx_data_ready;

    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active;
    logic       tx_done;

    logic       rx_dv;
    logic [7:0] rx_byte;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock     (clk_i),
        .i_Tx_DV     (tx_dv),
        .i_Tx_Byte   (tx_byte),
        .o_Tx_Active (tx_active),
        .o_Tx_Serial (uart_tx_o),
        .o_Tx_Done   (tx_done)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock     (clk_i),
        .i_Rx_Serial (uart_rx_i),
        .o_Rx_DV     (rx_dv),
        .o_Rx_Byte   (rx_byte)
    );

    logic [7:0] tx_pending_data;
    logic       tx_pending;

    logic reading_uart_rx;
    assign reading_uart_rx = (addr_i == 32'h0201C) && !we_i;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_tx_data    <= '0;
            uart_rx_data    <= '0;
            tx_busy         <= 1'b0;
            rx_data_ready   <= 1'b0;
            tx_dv           <= 1'b0;
            tx_byte         <= '0;
            tx_pending      <= 1'b0;
            tx_pending_data <= '0;
        end else begin
            if (we_i && addr_i == 32'h02018) begin
                uart_tx_data <= wdata_i[7:0];
                if (!tx_active && !tx_pending) begin
                    tx_byte <= wdata_i[7:0];
                    tx_dv   <= 1'b1;
                end else begin
                    tx_pending_data <= wdata_i[7:0];
                    tx_pending      <= 1'b1;
                end
            end else begin
                tx_dv <= 1'b0;
            end

            if (tx_done && tx_pending) begin
                tx_byte    <= tx_pending_data;
                tx_dv      <= 1'b1;
                tx_pending <= 1'b0;
            end

            tx_busy <= tx_active || tx_pending;

            if (rx_dv) begin
                uart_rx_data  <= rx_byte;
                rx_data_ready <= 1'b1;
            end else if (reading_uart_rx) begin
                rx_data_ready <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. SPI periférico (instancia de spi_periph)
    // =========================================================================
    logic [31:0] spi_rdata;

    spi_periph #(
        .CLK_DIV(SPI_CLK_DIV)
    ) u_spi (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .addr_i     (addr_i),
        .wdata_i    (wdata_i),
        .we_i       (we_i),
        .rdata_o    (spi_rdata),
        .spi_sck_o  (spi_sck_o),
        .spi_mosi_o (spi_mosi_o),
        .spi_miso_i (spi_miso_i),
        .spi_cs_n_o (spi_cs_n_o)
    );

    // =========================================================================
    // 5. Multiplexor de lectura unificado
    // =========================================================================
    always_comb begin
        case (addr_i)
            // UART
            32'h02000: rdata_o = {16'b0, sw_stable};
            32'h02004: rdata_o = led_reg;
            32'h02010: rdata_o = {30'b0, rx_data_ready, tx_busy};
            32'h02018: rdata_o = {24'b0, uart_tx_data};
            32'h0201C: rdata_o = {24'b0, uart_rx_data};
            // SPI (delegado a spi_periph)
            32'h02020,
            32'h02028,
            32'h0202C: rdata_o = spi_rdata;
            default:   rdata_o = 32'b0;
        endcase
    end

endmodule