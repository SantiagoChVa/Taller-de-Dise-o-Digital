module bus_driver (
    input  logic        clk_i,
    input  logic        rst_i,

    // PicoRV32
    input  logic        mem_valid,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [ 3:0] mem_wstrb,
    output logic        mem_ready,
    output logic [31:0] mem_rdata,

    // ROM
    output logic [ 8:0] rom_addr,
    input  logic [31:0] rom_data,

    // RAM
    output logic [14:0] ram_addr,
    output logic [31:0] ram_wdata,
    output logic [ 3:0] ram_we,
    input  logic [31:0] ram_rdata,

    // LEDs y switches
    output logic [15:0] led_reg,
    input  logic [15:0] sw_reg,

    // UART
    output logic        uart_tx_dv,
    input  logic        uart_tx_active,
    input  logic        uart_tx_done,
    output logic [ 7:0] uart_tx_byte,
    input  logic        uart_rx_dv,
    input  logic [ 7:0] uart_rx_byte
);

    // ── registros internos de periféricos ──────────────────────
    logic [31:0] uart_ctrl_reg;   // 0x02010: bit0=send, bit1=new_rx
    logic [31:0] uart_data0_reg;  // 0x02018: dato a transmitir
    logic [31:0] uart_data1_reg;  // 0x0201C: dato recibido

    // ── latencia BRAM: contador de 2 ciclos ────────────────────
    logic        waiting;
    logic        wait_cnt;

    // ── capturar byte recibido por UART ────────────────────────
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            uart_data1_reg <= '0;
            uart_ctrl_reg  <= '0;
        end else begin
            // Cuando llega un byte nuevo del RX, guardarlo y setear new_rx
            if (uart_rx_dv) begin
                uart_data1_reg        <= {24'b0, uart_rx_byte};
                uart_ctrl_reg[1]      <= 1'b1;  // new_rx = 1
            end
            // Cuando TX termina, limpiar el bit send
            if (uart_tx_done) begin
                uart_ctrl_reg[0]      <= 1'b0;  // send = 0
            end
        end
    end

    // ── lógica de mem_ready (maneja latencia de BRAM) ──────────
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            mem_ready <= 1'b0;
            waiting   <= 1'b0;
            wait_cnt  <= 1'b0;
        end else begin
            mem_ready <= 1'b0;  // default: no listo

            if (mem_valid && !mem_ready) begin

                // Periféricos: responden en 1 ciclo
                if (mem_addr == 32'h02000 ||
                    mem_addr == 32'h02004 ||
                    mem_addr == 32'h02010 ||
                    mem_addr == 32'h02018 ||
                    mem_addr == 32'h0201C) begin
                    mem_ready <= 1'b1;
                    waiting   <= 1'b0;
                    wait_cnt  <= 1'b0;

                // ROM y RAM: esperan 2 ciclos de BRAM
                end else if (!waiting) begin
                    waiting  <= 1'b1;
                    wait_cnt <= 1'b0;
                end else begin
                    if (wait_cnt == 1'b1) begin
                        mem_ready <= 1'b1;
                        waiting   <= 1'b0;
                        wait_cnt  <= 1'b0;
                    end else begin
                        wait_cnt <= 1'b1;
                    end
                end

            end
        end
    end

    // ── lógica combinacional: mux de lectura y escritura ───────
    always_comb begin
        // defaults
        mem_rdata    = 32'h0;
        rom_addr     = 9'h0;
        ram_addr     = 15'h0;
        ram_we       = 4'h0;
        ram_wdata    = 32'h0;
        uart_tx_dv   = 1'b0;
        uart_tx_byte = 8'h0;

        // ── ROM: 0x0000 – 0x0FFF ───────────────────────────────
        if (mem_addr >= 32'h0000 && mem_addr <= 32'h0FFF) begin
            rom_addr  = mem_addr[10:2];
            mem_rdata = rom_data;

        // ── Switches/Botones: 0x02000 ──────────────────────────
        end else if (mem_addr == 32'h02000) begin
            mem_rdata = {16'b0, sw_reg};

        // ── LEDs: 0x02004 ──────────────────────────────────────
        end else if (mem_addr == 32'h02004) begin
            mem_rdata = {16'b0, led_reg};

        // ── UART control: 0x02010 ──────────────────────────────
        end else if (mem_addr == 32'h02010) begin
            mem_rdata = uart_ctrl_reg;
            // escritura: el programa pone send=1
            if (mem_wstrb != 4'h0) begin
                // si escribe bit0 (send), disparar TX
                if (mem_wdata[0] && !uart_tx_active) begin
                    uart_tx_dv   = 1'b1;
                    uart_tx_byte = uart_data0_reg[7:0];
                end
            end

        // ── UART data0 (TX): 0x02018 ───────────────────────────
        end else if (mem_addr == 32'h02018) begin
            mem_rdata = uart_data0_reg;

        // ── UART data1 (RX): 0x0201C ───────────────────────────
        end else if (mem_addr == 32'h0201C) begin
            mem_rdata = uart_data1_reg;
            // leer data1 limpia el bit new_rx (lo maneja el ff de arriba
            // pero el programa debe escribir 0 al ctrl)

        // ── RAM: 0x40000 – 0x7FFFF ─────────────────────────────
        end else if (mem_addr >= 32'h40000 && mem_addr <= 32'h7FFFF) begin
            ram_addr  = mem_addr[16:2];
            ram_wdata = mem_wdata;
            ram_we    = mem_wstrb;
            mem_rdata = ram_rdata;
        end
    end

    // ── escritura de registros de periféricos (secuencial) ─────
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            led_reg       <= '0;
            uart_data0_reg <= '0;
        end else if (mem_valid && mem_ready && mem_wstrb != 4'h0) begin
            case (mem_addr)
                32'h02004: led_reg        <= mem_wdata[15:0];
                32'h02018: uart_data0_reg <= mem_wdata;
                32'h02010: begin
                    // limpiar new_rx si el programa escribe 0 en bit1
                    uart_ctrl_reg[1] <= mem_wdata[1];
                end
                default: ;
            endcase
        end
    end

endmodule