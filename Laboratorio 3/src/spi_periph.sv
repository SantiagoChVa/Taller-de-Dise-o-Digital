// =============================================================================
// spi_periph.sv
// Periférico SPI para el ADXL362 (Nexys4 DDR).
//
// Mapa de registros (según Figura 4 del instructivo):
//   0x02020  SPI_CTRL  — Control/Estado  [solo lectura desde el CPU]
//              bit 0 = SPI_BUSY   : transacción en curso
//              bit 1 = RX_READY   : byte recibido disponible
//   0x02028  SPI_TX    — Dato a transmitir [escritura inicia transacción]
//   0x0202C  SPI_RX    — Dato recibido    [lectura limpia RX_READY]
//
// Protocolo SPI para ADXL362:
//   - Modo 0 (CPOL=0, CPHA=0): muestreo en flanco de subida, cambio en bajada
//   - MSB primero
//   - CS activo bajo
//   - Reloj SPI = clk_i / (2 * CLK_DIV)  →  con clk=10 MHz y CLK_DIV=5 → 1 MHz
//
// Uso típico desde el ensamblador RISC-V:
//   1. Escribir byte en SPI_TX  → la transacción arranca automáticamente.
//   2. Esperar SPI_BUSY = 0  (polling SPI_CTRL bit 0).
//   3. Leer SPI_RX para obtener el byte recibido (simultáneo al TX en SPI).
//
// Nota: CS es controlado automáticamente por este módulo para cada byte.
// Para transacciones multi-byte (p.e., leer 3 ejes del ADXL362), el firmware
// debe mantener CS bajo entre bytes. Se provee un bit CS_HOLD en SPI_TX[8]
// para ese propósito:
//   - SPI_TX[7:0] = byte a enviar
//   - SPI_TX[8]  = 1 → mantener CS bajo al terminar este byte (más bytes)
//                = 0 → liberar CS al terminar (fin de transacción)
// =============================================================================
module spi_periph #(
    parameter int CLK_DIV = 5   // SPI_CLK = clk_i / (2*CLK_DIV)
)(
    input  logic        clk_i,
    input  logic        rst_i,

    // --- Interfaz con el bus driver ---
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        we_i,
    output logic [31:0] rdata_o,

    // --- Señales SPI físicas (hacia ADXL362 en Nexys4) ---
    output logic        spi_sck_o,   // Reloj SPI
    output logic        spi_mosi_o,  // Master Out Slave In
    input  logic        spi_miso_i,  // Master In Slave Out
    output logic        spi_cs_n_o   // Chip Select (activo bajo)
);

    // =========================================================================
    // Registros internos
    // =========================================================================
    logic [7:0]  tx_data;        // Byte pendiente de transmisión
    logic        tx_cs_hold;     // 1 = mantener CS tras este byte
    logic        tx_pending;     // Hay transacción pendiente

    logic [7:0]  rx_data;        // Último byte recibido
    logic        rx_ready;       // Flag: dato listo para leer

    logic        busy;           // Transacción en curso

    // =========================================================================
    // Detección de lectura de SPI_RX (para limpiar rx_ready)
    // =========================================================================
    logic reading_rx;
    assign reading_rx = (addr_i == 32'h0202C) && !we_i;

    // =========================================================================
    // Escritura en registros (desde CPU)
    // =========================================================================
    
    logic        tx_start;                  // Pulso: iniciar transmisión
    
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            tx_data    <= '0;
            tx_cs_hold <= 1'b0;
            tx_pending <= 1'b0;
        end else begin
            if (we_i && addr_i == 32'h02028) begin
                tx_data    <= wdata_i[7:0];
                tx_cs_hold <= wdata_i[8];   // bit 8 = CS_HOLD
                tx_pending <= 1'b1;
            end else if (tx_start) begin
                tx_pending <= 1'b0;         // lo consume el motor SPI
            end
        end
    end

    // =========================================================================
    // Motor SPI (FSM)
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        TRANS = 2'd1,
        HOLD  = 2'd2
    } spi_state_t;

    spi_state_t  state;
    logic [$clog2(CLK_DIV)-1:0] clk_cnt;   // Divisor de reloj
    logic [3:0]  bit_cnt;                   // 0..7 (bit actual)
    logic [7:0]  shift_tx;                  // Registro de desplazamiento TX
    logic [7:0]  shift_rx;                  // Registro de desplazamiento RX
    logic        sck_r;                     // Valor actual del SCK
    logic        cs_hold_r;                 // CS_HOLD del byte en curso
    

    assign tx_start = (state == IDLE) && tx_pending;
    assign busy = (state != IDLE) || (we_i && addr_i == 32'h02028);

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state      <= IDLE;
            clk_cnt    <= '0;
            bit_cnt    <= '0;
            shift_tx   <= '0;
            shift_rx   <= '0;
            sck_r      <= 1'b0;
            spi_cs_n_o <= 1'b1;
            spi_mosi_o <= 1'b0;
            rx_data    <= '0;
            rx_ready   <= 1'b0;
            cs_hold_r  <= 1'b0;
        end else begin
            // Limpiar rx_ready al leer SPI_RX
            if (reading_rx)
                rx_ready <= 1'b0;

            case (state)
                // ---------------------------------------------------------
                IDLE: begin
                    sck_r   <= 1'b0;
                    if (tx_start) begin
                        shift_tx   <= tx_data;
                        cs_hold_r  <= tx_cs_hold;
                        spi_cs_n_o <= 1'b0;   // Activar CS
                        clk_cnt    <= '0;
                        bit_cnt    <= 4'd7;
                        state      <= TRANS;
                    end
                end

                // ---------------------------------------------------------
                // Cada bit: fase baja luego fase alta del SCK
                // CPOL=0 CPHA=0 → datos válidos en flanco de subida
                // ---------------------------------------------------------
                TRANS: begin
                    if (clk_cnt < CLK_DIV - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= '0;
                        sck_r   <= ~sck_r;

                        if (!sck_r) begin
                            // Flanco de bajada: poner el bit en MOSI
                            spi_mosi_o <= shift_tx[7];
                            shift_tx   <= {shift_tx[6:0], 1'b0};
                        end else begin
                            // Flanco de subida: capturar MISO
                            shift_rx <= {shift_rx[6:0], spi_miso_i};

                            if (bit_cnt == 0) begin
                                // Byte completo
                                rx_data  <= {shift_rx[6:0], spi_miso_i};
                                rx_ready <= 1'b1;
                                sck_r    <= 1'b0;

                                if (cs_hold_r)
                                    state <= HOLD;
                                else begin
                                    spi_cs_n_o <= 1'b1;  // Liberar CS
                                    state      <= IDLE;
                                end
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                            end
                        end
                    end
                end

                // ---------------------------------------------------------
                // HOLD: CS sigue bajo, esperando el siguiente byte
                // ---------------------------------------------------------
                HOLD: begin
                    if (tx_pending) begin
                        // Nuevo byte listo: continuar sin liberar CS
                        shift_tx  <= tx_data;
                        cs_hold_r <= tx_cs_hold;
                        clk_cnt   <= '0;
                        bit_cnt   <= 4'd7;
                        state     <= TRANS;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // El SCK sale del registro sck_r
    assign spi_sck_o = sck_r;

    // =========================================================================
    // Multiplexor de lectura
    // =========================================================================
    always_comb begin
        case (addr_i)
            32'h02020: rdata_o = {30'b0, rx_ready, busy};
            32'h02028: rdata_o = {23'b0, tx_cs_hold, tx_data};
            32'h0202C: rdata_o = {24'b0, rx_data};
            default:   rdata_o = 32'b0;
        endcase
    end

endmodule
