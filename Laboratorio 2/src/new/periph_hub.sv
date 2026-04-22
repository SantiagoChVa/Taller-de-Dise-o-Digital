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
//
// Comportamiento UART mejorado:
//   - Escribir en UART_TX inicia la transmisión automáticamente.
//   - Leer UART_RX devuelve el último byte recibido y limpia el flag new_rx.
//   - UART_CTRL: bit0 = TX_BUSY, bit1 = RX_DATA_READY.
// =============================================================================
module periph_hub #(
    parameter int DEBOUNCE_CYCLES = 50_000,
    parameter int CLKS_PER_BIT    = 87
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
    input  logic        uart_rx_i
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

    // --- Señales del módulo TX ---
    logic       tx_dv;
    logic [7:0] tx_byte;
    logic       tx_active;
    logic       tx_done;

    // --- Señales del módulo RX ---
    logic       rx_dv;
    logic [7:0] rx_byte;

    // Instancia TX
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock     (clk_i),
        .i_Tx_DV     (tx_dv),
        .i_Tx_Byte   (tx_byte),
        .o_Tx_Active (tx_active),
        .o_Tx_Serial (uart_tx_o),
        .o_Tx_Done   (tx_done)
    );

    // Instancia RX
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock     (clk_i),
        .i_Rx_Serial (uart_rx_i),
        .o_Rx_DV     (rx_dv),
        .o_Rx_Byte   (rx_byte)
    );

    // Buffer para TX pendiente
    logic [7:0] tx_pending_data;
    logic       tx_pending;

    // Detección de lectura de RX (para limpiar el flag)
    logic reading_rx;
    assign reading_rx = (addr_i == 32'h0201C) && !we_i;

    // =========================================================================
    // BLOQUE ÚNICO para registros UART
    // =========================================================================
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
            // -------------------------------------------------------------
            // ESCRITURA en UART_TX (0x02018)
            // -------------------------------------------------------------
            if (we_i && addr_i == 32'h02018) begin
                uart_tx_data <= wdata_i[7:0];  // guardar para lectura
                if (!tx_active && !tx_pending) begin
                    // TX libre: iniciar inmediatamente
                    tx_byte <= wdata_i[7:0];
                    tx_dv   <= 1'b1;
                end else begin
                    // TX ocupado: guardar para después
                    tx_pending_data <= wdata_i[7:0];
                    tx_pending      <= 1'b1;
                end
            end else begin
                tx_dv <= 1'b0;
            end

            // -------------------------------------------------------------
            // LÓGICA DE TX PENDIENTE
            // -------------------------------------------------------------
            if (tx_done && tx_pending) begin
                tx_byte      <= tx_pending_data;
                tx_dv        <= 1'b1;
                tx_pending   <= 1'b0;
            end

            // Actualizar tx_busy
            tx_busy <= tx_active || tx_pending;

            // -------------------------------------------------------------
            // RECEPCIÓN RX
            // -------------------------------------------------------------
            // Prioridad: si llega dato nuevo (rx_dv), actualizar inmediatamente.
            // Si no hay dato nuevo pero se está leyendo, limpiar el flag.
            if (rx_dv) begin
                uart_rx_data  <= rx_byte;
                rx_data_ready <= 1'b1;
            end else if (reading_rx) begin
                rx_data_ready <= 1'b0;
            end
        end
    end

    // =========================================================================
    // 4. Multiplexor de lectura
    // =========================================================================
    always_comb begin
        case (addr_i)
            32'h02000: rdata_o = {16'b0, sw_stable};
            32'h02004: rdata_o = led_reg;
            32'h02010: rdata_o = {30'b0, rx_data_ready, tx_busy};
            32'h02018: rdata_o = {24'b0, uart_tx_data};  // TX data (lectura del último byte enviado)
            32'h0201C: rdata_o = {24'b0, uart_rx_data};
            default:   rdata_o = 32'b0;
        endcase
    end

endmodule
