// =============================================================================
// bus_driver.sv
// Módulo de interconexión entre el núcleo RISC-V, la RAM y el periph_hub.
//
// Mapa de memoria:
//   0x00000 – 0x00FFF  → ROM  (instrucciones, no pasa por aquí)
//   0x40000 – 0x7FFFF  → RAM  (100 KB, latencia 1 ciclo)
//   0x02000 – 0x0202F  → Periféricos vía periph_hub
//                         0x02000  SW/BTN
//                         0x02004  LEDs
//                         0x02010  UART_CTRL
//                         0x02018  UART_TX
//                         0x0201C  UART_RX
//                         0x02020  SPI_CTRL   ← NUEVO
//                         0x02028  SPI_TX     ← NUEVO
//                         0x0202C  SPI_RX     ← NUEVO
//
// Política de latencia unificada (1 ciclo para todo):
//   Ciclo 0: addr/wdata/we entran al bus_driver. Se decodifica sel.
//            RAM recibe addr+wdata+we de forma combinacional.
//            periph_hub recibe addr+wdata+we de forma combinacional.
//   Ciclo 1: sel_q decide el mux. RAM presenta douta. periph_hub
//            presenta rdata_o basado en addr.
//
// NOTA sobre la decodificación de periféricos:
//   El rango original era 0x02000–0x0201F (bits [31:5] == 27'h100).
//   Con SPI el rango se amplía a 0x02000–0x0202F (32 bytes + 16 bytes = 48 bytes).
//   Usamos bits [31:6] == 26'h80 para cubrir 0x02000–0x0203F (64 bytes),
//   lo que incluye todos los registros actuales y deja margen para crecer.
// =============================================================================
module bus_driver (
    input  logic        clk_i,
    input  logic        rst_i,
    // Desde el núcleo
    input  logic [31:0] DataAddress_i,
    input  logic [31:0] DataOut_i,
    input  logic        we_i,
    // Hacia/desde RAM (IP Core Vivado, latencia 1 ciclo)
    output logic [14:0] ram_addr_o,
    output logic [31:0] ram_wdata_o,
    output logic [ 0:0] ram_we_o,
    input  logic [31:0] ram_rdata_i,
    // Hacia/desde periph_hub (latencia 1 ciclo)
    output logic [31:0] periph_addr_o,
    output logic [31:0] periph_wdata_o,
    output logic        periph_we_o,
    input  logic [31:0] periph_rdata_i,
    // Dato leído hacia el núcleo (válido en ciclo+1)
    output logic [31:0] DataIn_o
);
    // ------------------------------------------------------------------
    // Decodificación combinacional de destino (ciclo 0)
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {
        SEL_RAM    = 2'd0,
        SEL_PERIPH = 2'd1,
        SEL_NONE   = 2'd2
    } sel_t;

    sel_t sel;

    always_comb begin
        // ---------------------------------------------------------------
        // Periféricos: 0x02000 – 0x0203F
        //   bits [31:6] = 26'h80  →  cubre exactamente 0x02000..0x0203F
        //   (64 bytes = todos los registros UART + SPI + SW + LED)
        // ---------------------------------------------------------------
        if (DataAddress_i[31:6] == 26'h80)
            sel = SEL_PERIPH;
        // ---------------------------------------------------------------
        // RAM: 0x40000 – 0x7FFFF  (bits [19:18] == 2'b01)
        // ---------------------------------------------------------------
        else if (DataAddress_i[19:18] == 2'b01)
            sel = SEL_RAM;
        else
            sel = SEL_NONE;
    end

    // ------------------------------------------------------------------
    // RAM — señales combinacionales (IP Vivado registra internamente)
    // ------------------------------------------------------------------
    assign ram_addr_o  = DataAddress_i[16:2];
    assign ram_wdata_o = DataOut_i;
    assign ram_we_o    = (sel == SEL_RAM && we_i) ? 1'b1 : 1'b0;

    // ------------------------------------------------------------------
    // periph_hub — señales combinacionales
    // ------------------------------------------------------------------
    assign periph_addr_o  = DataAddress_i;
    assign periph_wdata_o = DataOut_i;
    assign periph_we_o    = (sel == SEL_PERIPH) && we_i;

    // ------------------------------------------------------------------
    // Pipeline de 1 etapa: solo sel (para alinear con ram_rdata_i)
    // ------------------------------------------------------------------
    sel_t sel_q;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            sel_q <= SEL_NONE;
        end else begin
            sel_q <= sel;
        end
    end

    // ------------------------------------------------------------------
    // Multiplexor de lectura
    // ------------------------------------------------------------------
    always_comb begin
        case (sel_q)
            SEL_RAM:    DataIn_o = ram_rdata_i;
            SEL_PERIPH: DataIn_o = periph_rdata_i;
            default:    DataIn_o = 32'b0;
        endcase
    end

endmodule