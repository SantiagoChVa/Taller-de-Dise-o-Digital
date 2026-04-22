// =============================================================================
// riscv_core_wrapper.sv
// Wrapper del core PicoRV32 con latencia de memoria de 1 ciclo.
//
// El PicoRV32 usa un bus unificado (mem_valid/mem_instr/mem_ready).
// Este wrapper lo separa en dos interfaces:
//   - Programa (ROM): ProgAddress_o / ProgIn_i   → cuando mem_instr = 1
//   - Datos (bus):    DataAddress_o / DataOut_o / DataIn_i / we_o
//                                                 → cuando mem_instr = 0
//
// IMPORTANTE sobre la dirección:
//   PicoRV32 presenta mem_addr válido en el mismo ciclo que mem_valid.
//   Ambas interfaces comparten mem_addr porque el core nunca hace fetch
//   y acceso a dato simultáneamente.
//
// Latencia de 1 ciclo:
//   Ciclo 0: mem_valid sube, mem_addr/mem_wdata válidos.
//            ROM/RAM/periph_hub reciben dirección y dato.
//   Ciclo 1: mem_ready = 1, dato disponible en mem_rdata.
// =============================================================================
module riscv_core_wrapper (
    input  logic        clk_i,
    input  logic        rst_i,

    // Interfaz de programa (ROM)
    output logic [31:0] ProgAddress_o,
    input  logic [31:0] ProgIn_i,

    // Interfaz de datos (bus_driver → RAM / periféricos)
    output logic [31:0] DataAddress_o,
    output logic [31:0] DataOut_o,
    input  logic [31:0] DataIn_i,
    output logic        we_o
);

    // ------------------------------------------------------------------
    // Señales internas PicoRV32
    // ------------------------------------------------------------------
    logic        mem_valid;
    logic        mem_instr;
    logic        mem_ready;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [ 3:0] mem_wstrb;
    logic [31:0] mem_rdata;

    // ------------------------------------------------------------------
    // Instancia PicoRV32
    // ------------------------------------------------------------------
    picorv32 #(
        .ENABLE_MUL    (0),
        .ENABLE_DIV    (0),
        .ENABLE_IRQ    (0),
        .ENABLE_TRACE  (0),
        .REGS_INIT_ZERO(1)
    ) u_picorv32 (
        .clk       (clk_i),
        .resetn    (~rst_i),          // PicoRV32: reset activo bajo
        .trap      (),
        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),
        .irq       (32'b0),
        .eoi       ()
    );

    // ------------------------------------------------------------------
    // Interfaces de salida
    // mem_addr es válido en cuanto mem_valid sube; se presenta directo
    // a ROM y bus_driver.
    // ------------------------------------------------------------------
    assign ProgAddress_o = mem_addr;
    assign DataAddress_o = mem_addr;
    assign DataOut_o     = mem_wdata;
    assign we_o          = mem_valid && !mem_instr && (mem_wstrb != 4'b0);

    // ------------------------------------------------------------------
    // Latencia de 1 ciclo: mem_ready se activa un ciclo después de mem_valid
    // ------------------------------------------------------------------
    logic mem_valid_q;
    logic mem_instr_q;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            mem_valid_q <= 1'b0;
            mem_instr_q <= 1'b0;
        end else begin
            mem_valid_q <= mem_valid;
            mem_instr_q <= mem_instr;
        end
    end

    assign mem_ready = mem_valid_q;

    // ------------------------------------------------------------------
    // Selección de dato de retorno alineada con mem_ready
    // mem_instr_q indica si el acceso que completó era de instrucción
    // ------------------------------------------------------------------
    always_comb begin
        if (mem_instr_q)
            mem_rdata = ProgIn_i;
        else
            mem_rdata = DataIn_i;
    end

endmodule
