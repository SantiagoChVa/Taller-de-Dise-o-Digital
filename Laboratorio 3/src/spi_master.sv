// =============================================================================
// spi_master.sv  -  Maestro SPI para ADXL362 (Nexys 4 DDR)
//
// Interfaz con periph_hub:
//   ctrl_reg_i [7:4] = cmd   0 → WRITE (byte0 = 0x0A)
//                            1 → READ  (byte0 = 0x0B)
//   ctrl_reg_i [0]   = start (pulso de 1 ciclo, generado por periph_hub)
//   tx_reg_i  [15:8] = reg_addr del ADXL362
//   tx_reg_i  [ 7:0] = dato a escribir (0x00 en lecturas)
//
// Trama SPI - 3 bytes (24 bits), modo 0 (CPOL=0, CPHA=0), MSB first:
//   Byte 0 : 0x0A (WRITE) ó 0x0B (READ)
//   Byte 1 : reg_addr
//   Byte 2 : dato  (0x00 en READ para clocar el reloj y recibir respuesta)
//
// Salidas al periph_hub:
//   busy_o      → 1 mientras la transacción está en curso
//   rx_reg_o    → {24'b0, byte_recibido}   (SPI_RX  0x02028 read)
//   data_reg_o  → {24'b0, byte_recibido}   (SPI_DATA 0x0202C)
//
// Parámetro CLK_DIV:
//   Medio período de SCK = CLK_DIV+1 ciclos de clk_i
//   SCK = clk_i / (2*(CLK_DIV+1))
//   Con clk=10 MHz, CLK_DIV=4 → SCK = 1 MHz  (< 8 MHz máx ADXL362)
// =============================================================================

module spi_master #(
    parameter int CLK_DIV = 4
)(
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [31:0] ctrl_reg_i,   // [7:4]=cmd  [0]=start (pulso)
    input  logic [31:0] tx_reg_i,     // [15:8]=reg_addr  [7:0]=dato

    output logic [31:0] rx_reg_o,     // SPI_RX  : {24'b0, rx_byte}
    output logic [31:0] data_reg_o,   // SPI_DATA: {24'b0, rx_byte}
    output logic        busy_o,

    output logic        spi_sck_o,
    output logic        spi_mosi_o,
    input  logic        spi_miso_i,
    output logic        spi_cs_n_o
);

    // -------------------------------------------------------------------------
    localparam int      FRAME_BITS  = 24;
    localparam int      CNT_MAX     = CLK_DIV;      // medio período - 1
    localparam logic [7:0] CMD_WRITE = 8'h0A;
    localparam logic [7:0] CMD_READ  = 8'h0B;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        SETUP = 2'd1,   // CS_N baja, datos listos (1 ciclo)
        SHIFT = 2'd2,   // transferencia bit a bit
        DONE  = 2'd3    // CS_N sube, guardar rx_byte, 1 ciclo
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Registros
    // -------------------------------------------------------------------------
    logic [FRAME_BITS-1:0] tx_shift;          // shift register TX
    logic [FRAME_BITS-1:0] rx_shift;          // shift register RX
    logic [$clog2(FRAME_BITS):0]   bit_cnt;   // bits ya transferidos
    logic [$clog2(2*CNT_MAX+2):0]  clk_cnt;   // prescaler
    logic sck_r;
    logic [7:0] rx_byte_r;

    // -------------------------------------------------------------------------
    // Salidas
    // -------------------------------------------------------------------------
    assign spi_sck_o  = sck_r;
    // MOSI válido sólo durante SHIFT; en reposo = 0
    assign spi_mosi_o = (state == SHIFT) ? tx_shift[FRAME_BITS-1] : 1'b0;
    assign busy_o     = (state != IDLE);
    assign rx_reg_o   = {24'b0, rx_byte_r};
    assign data_reg_o = {24'b0, rx_byte_r};

    // -------------------------------------------------------------------------
    // FSM + datapath
    // -------------------------------------------------------------------------
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            state      <= IDLE;
            spi_cs_n_o <= 1'b1;
            sck_r      <= 1'b0;
            tx_shift   <= '0;
            rx_shift   <= '0;
            rx_byte_r  <= '0;
            bit_cnt    <= '0;
            clk_cnt    <= '0;
        end else begin
            case (state)

                // --------------------------------------------------------
                // IDLE - esperar pulso de start (1 ciclo, garantizado por
                // periph_hub). No hay transición por reset ni basura.
                // --------------------------------------------------------
                IDLE: begin
                    sck_r      <= 1'b0;
                    spi_cs_n_o <= 1'b1;
                    clk_cnt    <= '0;
                    bit_cnt    <= '0;
                    rx_shift   <= '0;

                    // start debe ser 1 Y el módulo debe estar realmente idle
                    if (ctrl_reg_i[0] == 1'b1) begin
                        // Armar trama: byte0=CMD, byte1=reg_addr, byte2=dato
                        if (ctrl_reg_i[4] == 1'b0)
                            tx_shift <= {CMD_WRITE, tx_reg_i[15:8], tx_reg_i[7:0]};
                        else
                            tx_shift <= {CMD_READ,  tx_reg_i[15:8], tx_reg_i[7:0]};
                        state <= SETUP;
                    end
                end

                // --------------------------------------------------------
                // SETUP - CS_N baja, SCK en reposo (=0). Dura 1 ciclo.
                // --------------------------------------------------------
                SETUP: begin
                    spi_cs_n_o <= 1'b0;
                    sck_r      <= 1'b0;
                    clk_cnt    <= '0;
                    state      <= SHIFT;
                end

                // --------------------------------------------------------
                // SHIFT - modo 0 (CPOL=0, CPHA=0):
                //   clk_cnt = 0..CNT_MAX-1  : SCK=0 (MOSI estable)
                //   clk_cnt = CNT_MAX        : SCK sube → capturar MISO
                //   clk_cnt = CNT_MAX+1..2*CNT_MAX : SCK=1
                //   clk_cnt = 2*CNT_MAX+1    : SCK baja → desplazar TX,
                //                              incrementar bit_cnt
                // --------------------------------------------------------
                SHIFT: begin
                    clk_cnt <= clk_cnt + 1;

                    // Flanco de SUBIDA de SCK → capturar MISO
                    if (clk_cnt == CNT_MAX) begin
                        sck_r    <= 1'b1;
                        rx_shift <= {rx_shift[FRAME_BITS-2:0], spi_miso_i};
                    end

                    // Flanco de BAJADA de SCK → avanzar TX
                    if (clk_cnt == (2 * CNT_MAX + 1)) begin
                        sck_r   <= 1'b0;
                        clk_cnt <= '0;
                        // Desplazar DESPUÉS de haber enviado el bit actual
                        tx_shift <= {tx_shift[FRAME_BITS-2:0], 1'b0};
                        bit_cnt  <= bit_cnt + 1;

                        if (bit_cnt == (FRAME_BITS - 1))
                            state <= DONE;
                    end
                end

                // --------------------------------------------------------
                // DONE - 1 ciclo: CS_N sube, guardar resultado
                // --------------------------------------------------------
                DONE: begin
                    spi_cs_n_o <= 1'b1;
                    sck_r      <= 1'b0;
                    rx_byte_r  <= rx_shift[7:0];   // byte recibido en la trama
                    state      <= IDLE;
                end

                default: begin
                    state      <= IDLE;
                    spi_cs_n_o <= 1'b1;
                    sck_r      <= 1'b0;
                end
            endcase
        end
    end

endmodule
