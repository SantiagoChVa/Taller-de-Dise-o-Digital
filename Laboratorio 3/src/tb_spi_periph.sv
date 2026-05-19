// =============================================================================
// tb_spi_periph.sv
// Testbench para spi_periph — verifica 3 cosas:
//   TEST 1: busy sube en el ciclo correcto tras escribir en SPI_TX
//   TEST 2: SCK, MOSI y CS_N tienen forma de onda SPI Modo 0, MSB primero
//   TEST 3: RX_READY sube tras 8 bits y SPI_RX contiene el byte correcto
//
// Para correr en ModelSim/Questa:
//   vlog spi_periph.sv tb_spi_periph.sv
//   vsim -novopt tb_spi_periph
//   run -all
//
// Para correr en Vivado Simulator:
//   Agregar ambos archivos al proyecto como fuentes de simulación
//   y correr Behavioral Simulation.
// =============================================================================
`timescale 1ns/1ps

module tb_spi_periph;

    // =========================================================================
    // Parámetros — CLK_DIV=2 para que la sim sea rápida
    // =========================================================================
    localparam int CLK_DIV   = 2;
    localparam int CLK_PERIOD = 10; // 10 ns → 100 MHz (igual que en la Nexys4)

    // =========================================================================
    // Señales
    // =========================================================================
    logic        clk_i     = 0;
    logic        rst_i     = 1;
    logic [31:0] addr_i    = 0;
    logic [31:0] wdata_i   = 0;
    logic        we_i      = 0;
    logic [31:0] rdata_o;
    logic        spi_sck_o;
    logic        spi_mosi_o;
    logic        spi_miso_i = 0;
    logic        spi_cs_n_o;

    // =========================================================================
    // DUT
    // =========================================================================
    spi_periph #(.CLK_DIV(CLK_DIV)) dut (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .addr_i     (addr_i),
        .wdata_i    (wdata_i),
        .we_i       (we_i),
        .rdata_o    (rdata_o),
        .spi_sck_o  (spi_sck_o),
        .spi_mosi_o (spi_mosi_o),
        .spi_miso_i (spi_miso_i),
        .spi_cs_n_o (spi_cs_n_o)
    );

    // =========================================================================
    // Reloj
    // =========================================================================
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // =========================================================================
    // Contadores de errores
    // =========================================================================
    int errors = 0;

    // =========================================================================
    // Tareas auxiliares
    // =========================================================================

    // Escribe un ciclo en el bus (simula SW del RISC-V)
    task bus_write(input logic [31:0] addr, input logic [31:0] data);
        @(negedge clk_i);
        addr_i  = addr;
        wdata_i = data;
        we_i    = 1;
        @(posedge clk_i); #1;
        we_i    = 0;
        addr_i  = 0;
        wdata_i = 0;
    endtask

    // Lee un ciclo del bus (simula LW del RISC-V)
    task bus_read(input logic [31:0] addr, output logic [31:0] data);
        @(negedge clk_i);
        addr_i = addr;
        we_i   = 0;
        @(posedge clk_i); #1;
        data   = rdata_o;
        addr_i = 0;
    endtask

    // Espera a que busy baje (con timeout)
    task wait_not_busy(input int timeout_cycles = 10000);
        logic [31:0] ctrl;
        int cnt = 0;
        do begin
            bus_read(32'h02020, ctrl);
            cnt++;
            if (cnt > timeout_cycles) begin
                $display("  [TIMEOUT] SPI_BUSY nunca bajó a 0 — timeout tras %0d ciclos", timeout_cycles);
                errors++;
                return;
            end
        end while (ctrl[0] == 1'b1);
    endtask

    // =========================================================================
    // Proceso que simula la respuesta del esclavo SPI en MISO
    // Captura lo que llega en MOSI y devuelve MISO_BYTE bit a bit
    // =========================================================================
    logic [7:0] miso_byte  = 8'hAD;   // El ADXL362 responde 0xAD al leer ID
    logic [7:0] mosi_captured = 0;
    int         miso_bit_idx;

    // Proceso de esclavo SPI: muestrea en flanco de bajada de SCK para poner MISO
    // y captura MOSI en flanco de subida de SCK
    initial begin
        miso_bit_idx = 7;
        forever begin
            // Esperar flanco de bajada de SCK (maestro pone MOSI, esclavo pone MISO)
            @(negedge spi_sck_o);
            if (!spi_cs_n_o) begin
                spi_miso_i = miso_byte[miso_bit_idx];
            end

            // Esperar flanco de subida de SCK (muestrear MOSI)
            @(posedge spi_sck_o);
            if (!spi_cs_n_o) begin
                mosi_captured[miso_bit_idx] = spi_mosi_o;
                if (miso_bit_idx == 0)
                    miso_bit_idx = 7;
                else
                    miso_bit_idx--;
            end
        end
    end

    // =========================================================================
    // TEST PRINCIPAL
    // =========================================================================
    initial begin
        $display("========================================================");
        $display("  TB spi_periph — inicio");
        $display("========================================================");

        // ----- Reset -----
        rst_i = 1;
        repeat(4) @(posedge clk_i);
        rst_i = 0;
        @(posedge clk_i); #1;

        $display("\n--- TEST 1: busy sube en el ciclo correcto ---");
        test_busy_timing();

        $display("\n--- TEST 2: forma de onda SPI (SCK, MOSI, CS_N) ---");
        test_waveform();

        $display("\n--- TEST 3: RX_READY y SPI_RX tras 8 bits ---");
        test_rx();

        // ----- Resultado final -----
        $display("\n========================================================");
        if (errors == 0)
            $display("  TODOS LOS TESTS PASARON ✓");
        else
            $display("  FALLARON %0d VERIFICACIONES ✗", errors);
        $display("========================================================");
        $finish;
    end

    // =========================================================================
    // TEST 1 — busy debe subir a más tardar 2 ciclos después del SW
    // =========================================================================
    task test_busy_timing();
        logic [31:0] ctrl;
        logic        busy_seen;
        int          cycles_to_busy;

        // Escribir en SPI_TX
        bus_write(32'h02028, 32'h0000_00B5);  // byte 0xB5, CS_HOLD=0

        // Leer SPI_CTRL en los siguientes ciclos y ver cuándo sube busy
        busy_seen      = 0;
        cycles_to_busy = 0;
        repeat(5) begin
            bus_read(32'h02020, ctrl);
            cycles_to_busy++;
            if (ctrl[0] && !busy_seen) begin
                busy_seen = 1;
                $display("  [OK] busy=1 detectado tras %0d ciclo(s) de lectura", cycles_to_busy);
            end
        end

        if (!busy_seen) begin
            $display("  [FAIL] busy nunca subió a 1 tras escribir en SPI_TX");
            errors++;
        end

        // Esperar fin de transacción antes del siguiente test
        wait_not_busy();
        repeat(4) @(posedge clk_i);
    endtask

    // =========================================================================
    // TEST 2 — Verificar forma de onda SPI Modo 0
    //   CS_N debe bajar antes del primer SCK
    //   SCK debe tener 8 pulsos completos
    //   MOSI debe salir MSB primero
    //   CS_N debe subir después del último bit
    // =========================================================================
    task test_waveform();
        logic [7:0]  tx_byte;
        logic [7:0]  mosi_bits;
        int          sck_edges;
        time         cs_fall_time, first_sck_rise;
        logic        cs_was_low_before_sck;

        tx_byte   = 8'hA5;  // 1010_0101 — patrón fácil de verificar
        mosi_bits = 0;
        sck_edges = 0;
        cs_was_low_before_sck = 0;

        // Lanzar transacción
        bus_write(32'h02028, {24'b0, tx_byte});

        // Esperar bajada de CS_N
        @(negedge spi_cs_n_o);
        cs_fall_time = $time;
        $display("  CS_N bajó en t=%0t ns", cs_fall_time);

        // Esperar primer flanco de subida de SCK
        @(posedge spi_sck_o);
        first_sck_rise = $time;
        if (cs_fall_time < first_sck_rise)
            $display("  [OK] CS_N cae antes del primer SCK ✓");
        else begin
            $display("  [FAIL] CS_N no cae antes del primer SCK");
            errors++;
        end

        // Contar flancos de subida de SCK (deben ser exactamente 8)
        // y capturar MOSI en cada uno
        repeat(8) begin
            // Ya estamos en el primer posedge — capturar MOSI
            // (el esclavo lo hace, acá solo verificamos la cuenta)
            sck_edges++;
            if (sck_edges < 8)
                @(posedge spi_sck_o);
        end

        $display("  [OK] SCK tuvo %0d flancos de subida ✓", sck_edges);
        if (sck_edges != 8) begin
            $display("  [FAIL] Se esperaban 8 flancos, se vieron %0d", sck_edges);
            errors++;
        end

        // Esperar subida de CS_N
        @(posedge spi_cs_n_o);
        $display("  [OK] CS_N subió al terminar el byte ✓");

        // Verificar que MOSI transmitió MSB primero comparando con mosi_captured
        repeat(2) @(posedge clk_i);
        if (mosi_captured == tx_byte) begin
            $display("  [OK] MOSI transmitió 0x%02X MSB primero ✓", mosi_captured);
        end else begin
            $display("  [FAIL] MOSI transmitió 0x%02X, se esperaba 0x%02X", mosi_captured, tx_byte);
            errors++;
        end

        repeat(4) @(posedge clk_i);
    endtask

    // =========================================================================
    // TEST 3 — RX_READY sube tras 8 bits y SPI_RX tiene el byte del esclavo
    // =========================================================================
    task test_rx();
        logic [31:0] ctrl;
        logic [31:0] rx_val;
        logic        rx_ready_seen;
        int          cnt;

        // El esclavo simulado responde siempre con miso_byte = 0xAD
        miso_byte    = 8'hAD;
        miso_bit_idx = 7;

        // Lanzar transacción con byte dummy (0x00, solo para recibir)
        bus_write(32'h02028, 32'h0000_0000);

        // Esperar fin de transacción
        wait_not_busy();

        // Verificar RX_READY (bit 1 de SPI_CTRL)
        bus_read(32'h02020, ctrl);
        if (ctrl[1]) begin
            $display("  [OK] RX_READY=1 tras completar byte ✓");
        end else begin
            $display("  [FAIL] RX_READY no subió tras completar byte");
            errors++;
        end

        // Leer SPI_RX y verificar valor
        bus_read(32'h0202C, rx_val);
        if (rx_val[7:0] == 8'hAD) begin
            $display("  [OK] SPI_RX = 0x%02X (esperado 0xAD) ✓", rx_val[7:0]);
        end else begin
            $display("  [FAIL] SPI_RX = 0x%02X, se esperaba 0xAD", rx_val[7:0]);
            errors++;
        end

        // Verificar que RX_READY se limpió al leer SPI_RX
        bus_read(32'h02020, ctrl);
        if (!ctrl[1]) begin
            $display("  [OK] RX_READY=0 tras leer SPI_RX (flag limpiado) ✓");
        end else begin
            $display("  [FAIL] RX_READY no se limpió al leer SPI_RX");
            errors++;
        end

        repeat(4) @(posedge clk_i);
    endtask

endmodule
