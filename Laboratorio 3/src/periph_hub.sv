// =============================================================================
// periph_hub.sv
//
// Mapa de memoria:
//   0x02000  SW/BTN        R    [15:0] = switches debounced
//   0x02004  LEDs          W    [15:0] = leds
//   0x02010  UART_CTRL     R    [0]=tx_busy  [1]=rx_ready
//   0x02018  UART_TX       W    [7:0]=byte a enviar
//   0x0201C  UART_RX       R    [7:0]=byte recibido
//   0x02020  SPI_CTRL      RW   write: [7:4]=cmd  [0]=start
//                               read:  [1]=busy   [0]=0
//   0x02028  SPI_TX (W) /  W    [15:8]=reg_addr  [7:0]=dato
//            SPI_RX (R)    R    [7:0]=byte recibido
//   0x0202C  SPI_DATA      R    [7:0]=byte recibido
//
// Protocolo de escritura SPI (desde el .S):
//   PASO 1: SW 0x02028 <- {reg_addr, dato}        (carga SPI_TX)
//   PASO 2: SW 0x02020 <- 0x01 (WRITE) / 0x11 (READ)  (start=1, cmd en [4])
//   PASO 3: poll LW 0x02020 bit[1] hasta busy=0
//   PASO 4: LW 0x0202C para leer resultado
//
// NOTA: NO se implementa auto-start al escribir SPI_TX porque el .S siempre
// escribe SPI_CTRL explícitamente. El auto-start previo causaba transacciones
// espurias durante el reset y entre operaciones normales.
// =============================================================================
module periph_hub #(
    parameter int DEBOUNCE_CYCLES = 50_000,
    parameter int CLKS_PER_BIT    = 87,
    parameter int SPI_CLK_DIV     = 4
)(
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    output logic [31:0] rdata_o,

    input  logic [15:0] sw_i,
    output logic [15:0] led_o,
    output logic        uart_tx_o,
    input  logic        uart_rx_i,

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
        else        begin sw_sync1 <= sw_i; sw_sync2 <= sw_sync1; end
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
        .i_Clock    (clk_i),     .i_Tx_DV    (tx_dv),
        .i_Tx_Byte  (tx_byte),   .o_Tx_Active(tx_active),
        .o_Tx_Serial(uart_tx_o), .o_Tx_Done  (tx_done)
    );
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock   (clk_i),     .i_Rx_Serial(uart_rx_i),
        .o_Rx_DV   (rx_dv),     .o_Rx_Byte  (rx_byte)
    );

    logic [7:0] tx_pending_data;
    logic       tx_pending;
    logic       reading_rx;
    assign reading_rx = (addr_i == 32'h0201C) && !we_i;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            uart_tx_data    <= '0; uart_rx_data <= '0;
            tx_busy         <= 1'b0; rx_data_ready <= 1'b0;
            tx_dv           <= 1'b0; tx_byte <= '0;
            tx_pending      <= 1'b0; tx_pending_data <= '0;
        end else begin
            tx_dv <= 1'b0;   // default: no disparar

            if (we_i && addr_i == 32'h02018) begin
                uart_tx_data <= wdata_i[7:0];
                if (!tx_active && !tx_pending) begin
                    tx_byte <= wdata_i[7:0];
                    tx_dv   <= 1'b1;
                end else begin
                    tx_pending_data <= wdata_i[7:0];
                    tx_pending      <= 1'b1;
                end
            end

            if (tx_done && tx_pending) begin
                tx_byte    <= tx_pending_data;
                tx_dv      <= 1'b1;
                tx_pending <= 1'b0;
            end
            tx_busy <= tx_active || tx_pending;

            if (rx_dv)            begin uart_rx_data <= rx_byte; rx_data_ready <= 1'b1; end
            else if (reading_rx)  rx_data_ready <= 1'b0;
        end
    end

    // =========================================================================
    // 4. SPI - registro de control y disparo
    //
    // El .S escribe:
    //   SPI_CTRL (0x02020) <- 0x01  (cmd=WRITE, start=1)  → bit[4]=0
    //   SPI_CTRL (0x02020) <- 0x11  (cmd=READ,  start=1)  → bit[4]=1
    //
    // spi_master recibe un pulso de 1 ciclo en ctrl_reg_i[0].
    // Para generarlo: detectamos el flanco de escritura en SPI_CTRL con bit[0]=1
    // y producimos exactamente 1 ciclo de start, luego lo borramos.
    // =========================================================================
    logic [31:0] spi_tx_reg;    // captura de SPI_TX
    logic [31:0] spi_ctrl_latch;// cmd latched (bits [7:4]) - sin bit start
    logic        spi_start_q;   // pulso de 1 ciclo hacia spi_master
    logic        spi_busy;

    // Captura SPI_TX al escribir en 0x02028
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) spi_tx_reg <= '0;
        else if (we_i && addr_i == 32'h02028) spi_tx_reg <= wdata_i;
    end

    // Latch de cmd y generación del pulso start (1 ciclo exacto)
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            spi_ctrl_latch <= '0;
            spi_start_q    <= 1'b0;
        end else begin
            // Por defecto: limpiar pulso al siguiente ciclo
            spi_start_q <= 1'b0;

            if (we_i && addr_i == 32'h02020 && wdata_i[0] == 1'b1 && !spi_busy) begin
                // Guardar cmd, generar pulso de start
                spi_ctrl_latch <= wdata_i;
                spi_start_q    <= 1'b1;
            end
        end
    end

    // ctrl_reg enviado al spi_master: cmd de latch + start = pulso
    wire [31:0] spi_ctrl_to_master = {spi_ctrl_latch[31:1], spi_start_q};

    // Registros de salida SPI
    logic [31:0] spi_rx_reg;
    logic [31:0] spi_data_reg;

    spi_master #(.CLK_DIV(SPI_CLK_DIV)) u_spi (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .ctrl_reg_i (spi_ctrl_to_master),
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
    //    SPI_CTRL read: [1]=busy, [0]=0 (start ya se autoclear en hardware)
    // =========================================================================
    always_comb begin
        case (addr_i)
            32'h02000: rdata_o = {16'b0, sw_stable};
            32'h02004: rdata_o = led_reg;
            32'h02010: rdata_o = {30'b0, rx_data_ready, tx_busy};
            32'h02018: rdata_o = {24'b0, uart_tx_data};
            32'h0201C: rdata_o = {24'b0, uart_rx_data};
            32'h02020: rdata_o = {30'b0, spi_busy, 1'b0};  // [1]=busy, [0]=0
            32'h02028: rdata_o = spi_rx_reg;
            32'h0202C: rdata_o = spi_data_reg;
            default:   rdata_o = 32'b0;
        endcase
    end

endmodule
