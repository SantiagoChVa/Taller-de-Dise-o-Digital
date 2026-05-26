// =============================================================================
// spi_master.sv  - v2
// Maestro SPI modo 0 (CPOL=0, CPHA=0) para ADXL362.
//
// CORRECCIONES v2:
//   1. cmd y tx_bytes se registran en el momento del start_pulse (latch interno),
//      no dependen de ctrl_reg_i combinacional durante la transacción.
//   2. shift_rx se inicializa a 0 en S_SETUP para evitar datos residuales.
//   3. start_pulse se genera sobre start_reg interno ya latcheado, no sobre
//      ctrl_reg_i directamente, eliminando la dependencia del auto-clear externo.
//
// Protocolo:
//   ctrl_reg_i[0]   = start  (nivel; periph_hub lo auto-limpia al ciclo siguiente)
//   ctrl_reg_i[7:4] = cmd    (0=WRITE 1=READ 2=RFIFO)
//   tx_reg_i[15:8]  = dirección registro ADXL362
//   tx_reg_i[7:0]   = dato (solo WRITE)
//   rx_reg_o[7:0]   = byte recibido (byte 3 de la trama)
//   data_reg_o[15:0]= {byte2, byte3} (RFIFO)
//   busy_o          = 1 mientras transacción activa
// =============================================================================
module spi_master #(
    parameter int CLK_DIV = 4
)(
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [31:0] ctrl_reg_i,
    input  logic [31:0] tx_reg_i,
    output logic [31:0] rx_reg_o,
    output logic [31:0] data_reg_o,
    output logic        busy_o,

    output logic        spi_sck_o,
    output logic        spi_mosi_o,
    input  logic        spi_miso_i,
    output logic        spi_cs_n_o
);

    // ------------------------------------------------------------------
    // Detección de flanco de start - robusto ante auto-clear externo
    // El flanco se detecta sobre ctrl_reg_i[0] con un registro retardado.
    // En el ciclo donde start sube se latcha cmd y tx_bytes.
    // ------------------------------------------------------------------
    logic start_prev;
    logic start_pulse;

    always_ff @(posedge clk_i or posedge rst_i)
        if (rst_i) start_prev <= 1'b0;
        else        start_prev <= ctrl_reg_i[0];

    assign start_pulse = ctrl_reg_i[0] & ~start_prev;

    // ------------------------------------------------------------------
    // Latch de comando y bytes TX en el momento del start_pulse
    // Así no importa que ctrl_reg_i cambie después.
    // ------------------------------------------------------------------
    logic [7:0] tx_b0_lat, tx_b1_lat, tx_b2_lat;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            tx_b0_lat <= '0;
            tx_b1_lat <= '0;
            tx_b2_lat <= '0;
        end else if (start_pulse) begin
            case (ctrl_reg_i[7:4])
                4'd0: begin  // WRITE
                    tx_b0_lat <= 8'h0A;
                    tx_b1_lat <= tx_reg_i[15:8];
                    tx_b2_lat <= tx_reg_i[7:0];
                end
                4'd1: begin  // READ
                    tx_b0_lat <= 8'h0B;
                    tx_b1_lat <= tx_reg_i[15:8];
                    tx_b2_lat <= 8'h00;
                end
                4'd2: begin  // RFIFO
                    tx_b0_lat <= 8'h0D;
                    tx_b1_lat <= 8'h00;
                    tx_b2_lat <= 8'h00;
                end
                default: begin
                    tx_b0_lat <= 8'h00;
                    tx_b1_lat <= 8'h00;
                    tx_b2_lat <= 8'h00;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Divisor de reloj para SCK
    // ------------------------------------------------------------------
    logic [$clog2(CLK_DIV)-1:0] div_cnt;
    logic sck_tick;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) div_cnt <= '0;
        else if (div_cnt == CLK_DIV - 1) div_cnt <= '0;
        else div_cnt <= div_cnt + 1;
    end
    assign sck_tick = (div_cnt == CLK_DIV - 1);

    // ------------------------------------------------------------------
    // FSM SPI modo 0
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {
        S_IDLE  = 2'd0,
        S_SETUP = 2'd1,
        S_XFER  = 2'd2,
        S_HOLD  = 2'd3
    } state_t;

    state_t      state;
    logic [4:0]  bit_idx;
    logic        sck_phase;
    logic [23:0] shift_tx;
    logic [23:0] shift_rx;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state      <= S_IDLE;
            bit_idx    <= 5'd0;
            sck_phase  <= 1'b0;
            shift_tx   <= '0;
            shift_rx   <= '0;
            spi_cs_n_o <= 1'b1;
            spi_mosi_o <= 1'b0;
            spi_sck_o  <= 1'b0;
            busy_o     <= 1'b0;
        end else begin
            case (state)

                S_IDLE: begin
                    spi_cs_n_o <= 1'b1;
                    spi_sck_o  <= 1'b0;
                    spi_mosi_o <= 1'b0;
                    if (start_pulse) begin
                        busy_o    <= 1'b1;
                        bit_idx   <= 5'd0;
                        sck_phase <= 1'b0;
                        // Los bytes ya están latcheados en tx_b*_lat
                        // en este mismo ciclo de clock (start_pulse activo)
                        // PERO el latch ff actualiza al SIGUIENTE flanco.
                        // Por eso se usa shift_tx cargado en S_SETUP.
                        state     <= S_SETUP;
                    end
                end

                S_SETUP: begin
                    // Aquí tx_b*_lat ya tiene los valores correctos
                    // (latcheados en el ciclo anterior junto con start_pulse)
                    spi_cs_n_o <= 1'b0;
                    shift_rx   <= '0;   // limpiar residuo de transacción anterior
                    if (sck_tick) begin
                        shift_tx   <= {tx_b0_lat, tx_b1_lat, tx_b2_lat};
                        spi_mosi_o <= tx_b0_lat[7];
                        state      <= S_XFER;
                    end
                end

                S_XFER: begin
                    if (sck_tick) begin
                        sck_phase <= ~sck_phase;
                        if (!sck_phase) begin
                            // Flanco ascendente SCK: samplear MISO
                            spi_sck_o <= 1'b1;
                            shift_rx  <= {shift_rx[22:0], spi_miso_i};
                        end else begin
                            // Flanco descendente SCK: sacar siguiente MOSI
                            spi_sck_o <= 1'b0;
                            if (bit_idx == 5'd23) begin
                                state <= S_HOLD;
                            end else begin
                                bit_idx    <= bit_idx + 1;
                                shift_tx   <= {shift_tx[22:0], 1'b0};
                                spi_mosi_o <= shift_tx[22];
                            end
                        end
                    end
                end

                S_HOLD: begin
                    spi_cs_n_o <= 1'b1;
                    spi_sck_o  <= 1'b0;
                    spi_mosi_o <= 1'b0;
                    busy_o     <= 1'b0;
                    state      <= S_IDLE;
                end

            endcase
        end
    end

    // ------------------------------------------------------------------
    // Latch de recepción (se actualiza al entrar a S_HOLD)
    // ------------------------------------------------------------------
    logic [23:0] rx_latch;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) rx_latch <= '0;
        else if (state == S_HOLD) rx_latch <= shift_rx;
    end

    assign rx_reg_o   = {24'b0, rx_latch[7:0]};
    assign data_reg_o = {16'b0, rx_latch[15:8], rx_latch[7:0]};

endmodule
