// =============================================================================
// tb_spi_master.sv
// =============================================================================
`timescale 1ns/1ps

module tb_spi_master;

    localparam int CLK_PERIOD     = 100;
    localparam int CLK_DIV        = 4;
    localparam int FRAME_BITS     = 24;
    localparam int CYCLES_PER_BIT = 2 * (CLK_DIV + 1);

    // -------------------------------------------------------------------------
    // Señales
    // -------------------------------------------------------------------------
    logic        clk, rst;
    logic [31:0] ctrl_reg;
    logic [31:0] tx_reg;
    logic [31:0] rx_reg_o;
    logic [31:0] data_reg_o;
    logic        busy_o;
    logic        spi_sck;
    logic        spi_mosi;
    logic        spi_miso;
    logic        spi_cs_n;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    spi_master #(.CLK_DIV(CLK_DIV)) dut (
        .clk_i      (clk),
        .rst_i      (rst),
        .ctrl_reg_i (ctrl_reg),
        .tx_reg_i   (tx_reg),
        .rx_reg_o   (rx_reg_o),
        .data_reg_o (data_reg_o),
        .busy_o     (busy_o),
        .spi_sck_o  (spi_sck),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i (spi_miso),
        .spi_cs_n_o (spi_cs_n)
    );

    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Modelo MISO - modo 0 correcto
    //
    // El ADXL362 responde durante el tercer byte.
    // Presentamos la trama completa de 24 bits: [0x00, 0x00, miso_byte]
    //
    //   CS_N baja  → cargar shift y poner MSB en MISO inmediatamente
    //   SCK sube   → DUT muestrea (no hacemos nada aquí)
    //   SCK baja   → avanzar shift register, poner siguiente bit
    // -------------------------------------------------------------------------
    logic [7:0]  miso_byte;
    logic [23:0] miso_shift;

    // CS_N baja: cargar y presentar MSB
    always @(negedge spi_cs_n) begin
        miso_shift = {8'h00, 8'h00, miso_byte};
        spi_miso   = miso_shift[FRAME_BITS-1];
    end

    // SCK baja: avanzar al siguiente bit (ya fue muestreado en la subida)
    always @(negedge spi_sck) begin
        if (!spi_cs_n) begin
            miso_shift = {miso_shift[FRAME_BITS-2:0], 1'b0};
            spi_miso   = miso_shift[FRAME_BITS-1];
        end
    end

    // CS_N sube: MISO a 0
    always @(posedge spi_cs_n) spi_miso = 1'b0;

    // -------------------------------------------------------------------------
    // Captura MOSI en flanco de subida de SCK (modo 0)
    // -------------------------------------------------------------------------
    logic [FRAME_BITS-1:0] captured_mosi;
    integer                mosi_idx;

    always @(negedge spi_cs_n) begin
        captured_mosi = '0;
        mosi_idx      = FRAME_BITS - 1;
    end

    always @(posedge spi_sck) begin
        if (!spi_cs_n) begin
            captured_mosi[mosi_idx] = spi_mosi;
            mosi_idx                = mosi_idx - 1;
        end
    end

    // -------------------------------------------------------------------------
    // Tareas
    // -------------------------------------------------------------------------
    task automatic wait_clk(input int n);
        repeat (n) @(posedge clk);
    endtask

    task automatic spi_transaction(
        input logic       cmd,
        input logic [7:0] raddr,
        input logic [7:0] data
    );
        @(posedge clk); #1;
        tx_reg   = {16'b0, raddr, data};
        ctrl_reg = cmd ? 32'h00000011 : 32'h00000001;
        @(posedge clk); #1;
        ctrl_reg = 32'h00000000;
        wait (busy_o == 0);
        @(posedge clk);
    endtask

    task automatic check_mosi(
        input logic [7:0] b0, b1, b2,
        input string name
    );
        logic [23:0] exp;
        exp = {b0, b1, b2};
        if (captured_mosi === exp)
            $display("  [PASS] %s: MOSI=0x%06X  [0x%02X, 0x%02X, 0x%02X]",
                     name, captured_mosi, captured_mosi[23:16],
                     captured_mosi[15:8], captured_mosi[7:0]);
        else begin
            $display("  [FAIL] %s: esperado 0x%06X, obtenido 0x%06X",
                     name, exp, captured_mosi);
            $display("         esperado [0x%02X,0x%02X,0x%02X]  obtenido [0x%02X,0x%02X,0x%02X]",
                     b0,b1,b2,
                     captured_mosi[23:16], captured_mosi[15:8], captured_mosi[7:0]);
        end
    endtask

    task automatic check_rx(input logic [7:0] exp, input string name);
        if (data_reg_o[7:0] === exp)
            $display("  [PASS] %s: RX=0x%02X", name, data_reg_o[7:0]);
        else
            $display("  [FAIL] %s: esperado 0x%02X, obtenido 0x%02X",
                     name, exp, data_reg_o[7:0]);
    endtask

    // -------------------------------------------------------------------------
    // Assertions de protocolo
    // -------------------------------------------------------------------------
    always @(posedge spi_sck)
        if (spi_cs_n)
            $display("  [PROTO-FAIL] SCK activo con CS_N=1  t=%0t", $time);

    always @(posedge spi_cs_n)
        if (spi_sck)
            $display("  [PROTO-FAIL] CS_N sube con SCK=1  t=%0t", $time);

    // -------------------------------------------------------------------------
    // Estímulos
    // -------------------------------------------------------------------------
    initial begin
        rst       = 1;
        ctrl_reg  = '0;
        tx_reg    = '0;
        spi_miso  = 0;
        miso_byte = 8'hAD;

        $display("=============================================================");
        $display("  TB spi_master  CLK=10MHz  CLK_DIV=%0d  SCK=1MHz", CLK_DIV);
        $display("  Ciclos/bit=%0d  Trama=24 bits", CYCLES_PER_BIT);
        $display("=============================================================");

        repeat(5) @(posedge clk);
        rst = 0;
        repeat(3) @(posedge clk);

        // -----------------------------------------------------------------
        $display("\n[TEST 1] WRITE reg=0x2D dato=0x02  (POWER_CTL = meas mode)");
        miso_byte = 8'h00;
        spi_transaction(0, 8'h2D, 8'h02);
        wait_clk(2);
        check_mosi(8'h0A, 8'h2D, 8'h02, "TEST1 MOSI");
        if (spi_cs_n === 1'b1) $display("  [PASS] TEST1: CS_N=1 tras transaccion");
        else                   $display("  [FAIL] TEST1: CS_N sigue bajo");
        if (busy_o  === 1'b0)  $display("  [PASS] TEST1: busy=0 tras transaccion");
        else                   $display("  [FAIL] TEST1: busy sigue en 1");
        wait_clk(5);

        // -----------------------------------------------------------------
        $display("\n[TEST 2] READ  reg=0x00  (DEVID)  MISO=0xAD");
        miso_byte = 8'hAD;
        spi_transaction(1, 8'h00, 8'h00);
        wait_clk(2);
        check_mosi(8'h0B, 8'h00, 8'h00, "TEST2 MOSI");
        check_rx(8'hAD, "TEST2 RX");
        wait_clk(5);

        // -----------------------------------------------------------------
        $display("\n[TEST 3] WRITE reg=0x1F dato=0x52  (SOFT_RESET)");
        miso_byte = 8'h00;
        spi_transaction(0, 8'h1F, 8'h52);
        wait_clk(2);
        check_mosi(8'h0A, 8'h1F, 8'h52, "TEST3 MOSI");
        wait_clk(5);

        // -----------------------------------------------------------------
        $display("\n[TEST 4] Doble start - segundo ignorado si busy=1");
        miso_byte = 8'h00;
        @(posedge clk); #1;
        tx_reg   = {16'b0, 8'h2D, 8'h02};
        ctrl_reg = 32'h00000001;
        @(posedge clk); #1;
        ctrl_reg = 32'h00000000;
        wait_clk(2);
        // Intentar segundo start con datos distintos
        @(posedge clk); #1;
        tx_reg   = {16'b0, 8'hFF, 8'hFF};
        ctrl_reg = 32'h00000001;
        @(posedge clk); #1;
        ctrl_reg = 32'h00000000;
        wait (busy_o == 0);
        wait_clk(2);
        check_mosi(8'h0A, 8'h2D, 8'h02, "TEST4 trama no corrompida");
        wait_clk(5);

        // -----------------------------------------------------------------
        $display("\n[TEST 5] READ  reg=0x0E  (XDATA_L)  MISO=0x55");
        miso_byte = 8'h55;
        spi_transaction(1, 8'h0E, 8'h00);
        wait_clk(2);
        check_mosi(8'h0B, 8'h0E, 8'h00, "TEST5 MOSI");
        check_rx(8'h55, "TEST5 RX");
        wait_clk(5);

        // -----------------------------------------------------------------
        $display("\n[TEST 6] Timing SCK = 1 MHz");
        begin
            time t1, t2;
            integer periodo_ns;
            miso_byte = 8'h00;
            @(posedge clk); #1;
            tx_reg   = {16'b0, 8'h2D, 8'h02};
            ctrl_reg = 32'h00000001;
            @(posedge clk); #1;
            ctrl_reg = 32'h00000000;
            @(posedge spi_sck); t1 = $time;
            @(posedge spi_sck); t2 = $time;
            periodo_ns = int'(t2 - t1);
            wait (busy_o == 0);
            wait_clk(2);
            if (periodo_ns == CLK_PERIOD * CYCLES_PER_BIT)
                $display("  [PASS] TEST6: periodo SCK=%0d ns (%.1f MHz)",
                         periodo_ns, 1000.0/periodo_ns);
            else
                $display("  [FAIL] TEST6: periodo SCK=%0d ns (esperado %0d ns)",
                         periodo_ns, CLK_PERIOD * CYCLES_PER_BIT);
        end

        // -----------------------------------------------------------------
        $display("\n[TEST 7] READ secuencial: X-Y-Z  (simula adxl_read_xyz)");
        begin
            logic [7:0] vals[6] = '{8'hE0, 8'h00,   // XDATA_L/H → X =  32
                                    8'hD8, 8'hFF,   // YDATA_L/H → Y = -40 (0xFFD8)
                                    8'h64, 8'h00};  // ZDATA_L/H → Z = 100
            logic [7:0] regs[6] = '{8'h0E, 8'h0F,
                                    8'h10, 8'h11,
                                    8'h12, 8'h13};
            logic [7:0] rx_vals[6];
            for (int i = 0; i < 6; i++) begin
                miso_byte = vals[i];
                spi_transaction(1, regs[i], 8'h00);
                wait_clk(2);
                rx_vals[i] = data_reg_o[7:0];
            end
            for (int i = 0; i < 6; i++) begin
                if (rx_vals[i] === vals[i])
                    $display("  [PASS] TEST7 reg=0x%02X: RX=0x%02X", regs[i], rx_vals[i]);
                else
                    $display("  [FAIL] TEST7 reg=0x%02X: esperado=0x%02X obtenido=0x%02X",
                             regs[i], vals[i], rx_vals[i]);
            end
        end

        wait_clk(10);
        $display("\n=============================================================");
        $display("  FIN DE TESTS");
        $display("=============================================================\n");
        $finish;
    end

    // Timeout de seguridad
    initial begin
        #10_000_000;
        $display("[TIMEOUT] Simulacion superó 10ms");
        $finish;
    end

    initial begin
        $dumpfile("tb_spi_master.vcd");
        $dumpvars(0, tb_spi_master);
    end

endmodule
