// =============================================================================
// bus_driver.sv  — MODIFICADO: rango de periféricos extendido a 0x02000–0x0202F
//
// Mapa de memoria:
//   0x00000 – 0x00FFF  → ROM
//   0x40000 – 0x7FFFF  → RAM
//   0x02000 – 0x0202F  → Periféricos (ampliado de 0x1F a 0x2F)
//
// El cambio único respecto al original es la condición de selección de
// periféricos: antes bits[31:5]==27'h100 (cubre 0x02000–0x0201F, 32 bytes).
// Ahora se decodifica el rango completo 0x02000–0x0202F (48 bytes) con
// bits[31:6]==26'h80 (0x02000>>6 = 0x80).
// =============================================================================
module bus_driver (
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [31:0] DataAddress_i,
    input  logic [31:0] DataOut_i,
    input  logic        we_i,

    output logic [14:0] ram_addr_o,
    output logic [31:0] ram_wdata_o,
    output logic [ 0:0] ram_we_o,
    input  logic [31:0] ram_rdata_i,

    output logic [31:0] periph_addr_o,
    output logic [31:0] periph_wdata_o,
    output logic        periph_we_o,
    input  logic [31:0] periph_rdata_i,

    output logic [31:0] DataIn_o
);

    typedef enum logic [1:0] {
        SEL_RAM    = 2'd0,
        SEL_PERIPH = 2'd1,
        SEL_NONE   = 2'd2
    } sel_t;

    sel_t sel;

    always_comb begin
        // Periféricos: 0x02000 – 0x0202F
        // bits[31:6] == 26'h80  (0x02000 >> 6 = 0x80)
        if (DataAddress_i[31:6] == 26'h80)
            sel = SEL_PERIPH;
        // RAM: 0x40000 – 0x7FFFF
        else if (DataAddress_i[19:18] == 2'b01)
            sel = SEL_RAM;
        else
            sel = SEL_NONE;
    end

    assign ram_addr_o  = DataAddress_i[16:2];
    assign ram_wdata_o = DataOut_i;
    assign ram_we_o    = (sel == SEL_RAM && we_i) ? 1'b1 : 1'b0;

    assign periph_addr_o  = DataAddress_i;
    assign periph_wdata_o = DataOut_i;
    assign periph_we_o    = (sel == SEL_PERIPH) && we_i;

    sel_t sel_q;
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) sel_q <= SEL_NONE;
        else        sel_q <= sel;
    end

    always_comb begin
        case (sel_q)
            SEL_RAM:    DataIn_o = ram_rdata_i;
            SEL_PERIPH: DataIn_o = periph_rdata_i;
            default:    DataIn_o = 32'b0;
        endcase
    end

endmodule
