//REVISAR LINEA 204 ANTES DE EJECUTAR

`timescale 1ns/1ps

module tb_top;

  localparam int CLK_PERIOD_NS = 10;
  localparam int CLKS_PER_BIT  = 87;
  localparam int BIT_TIME_NS   = CLKS_PER_BIT * CLK_PERIOD_NS;

  logic        clk_i;
  logic        rst_i;
  logic        uart_rx_i;
  logic        uart_tx_o;
  logic [15:0] leds_o;
  logic [15:0] sw_i;

  top dut (
    .clk_i     (clk_i),
    .rst_i     (rst_i),
    .uart_rx_i (uart_rx_i),
    .uart_tx_o (uart_tx_o),
    .leds_o    (leds_o),
    .sw_i      (sw_i)
  );

  // ── Reloj ──────────────────────────────────────────────────
  initial clk_i = 1'b0;
  always #(CLK_PERIOD_NS/2) clk_i = ~clk_i;

  // ── Reset ──────────────────────────────────────────────────
  task automatic reset_dut;
    begin
      rst_i     = 1'b1;
      uart_rx_i = 1'b1;
      sw_i      = 16'h0000;
      repeat (20) @(posedge clk_i);
      rst_i = 1'b0;
      $display("[RESET] rst_i bajado a 0, procesador liberado");
      repeat (20) @(posedge clk_i);
    end
  endtask

  // ── Mandar un byte por UART hacia el procesador ────────────
  task automatic uart_send_byte(input [7:0] data);
    integer i;
    begin
      uart_rx_i = 1'b0;
      #(BIT_TIME_NS);
      for (i = 0; i < 8; i++) begin
        uart_rx_i = data[i];
        #(BIT_TIME_NS);
      end
      uart_rx_i = 1'b1;
      #(BIT_TIME_NS);
      #(BIT_TIME_NS);
    end
  endtask

  // ── Capturar un byte que manda el procesador ───────────────
  task automatic uart_capture_byte(output [7:0] data);
    integer i;
    begin
      data = 8'h00;
      @(negedge uart_tx_o);
      #(BIT_TIME_NS + BIT_TIME_NS/2);
      for (i = 0; i < 8; i++) begin
        data[i] = uart_tx_o;
        #(BIT_TIME_NS);
      end
      #(BIT_TIME_NS);
    end
  endtask

  // ── Monitor de bus ─────────────────────────────────────────
  always @(posedge dut.clk) begin
    if (dut.mem_valid && dut.mem_ready) begin
      if (dut.mem_wstrb != 4'b0000)
        $display("[BUS  ] WRITE  addr=0x%08h  data=0x%08h  wstrb=%04b",
                 dut.mem_addr, dut.mem_wdata, dut.mem_wstrb);
      else
        $display("[BUS  ] READ   addr=0x%08h  data=0x%08h",
                 dut.mem_addr, dut.mem_rdata);
    end
  end

  // ── Monitor de LEDs ────────────────────────────────────────
  logic [15:0] leds_prev = 16'hFFFF;
  always @(posedge dut.clk) begin
    if (leds_o !== leds_prev) begin
      $display("[LEDs ] Cambiaron a 0x%04h  (binario: %016b)", leds_o, leds_o);
      leds_prev <= leds_o;
    end
  end

  // ── Monitor UART TX ────────────────────────────────────────
  initial begin
    logic [7:0] rxchar;
    forever begin
      uart_capture_byte(rxchar);
      if (rxchar >= 8'd32 && rxchar <= 8'd126)
        $display("[UART ] CPU mandó: '%s'  (0x%02h)", rxchar, rxchar);
      else if (rxchar == 8'h0A)
        $display("[UART ] CPU mandó: LF (salto de línea)");
      else if (rxchar == 8'h0D)
        $display("[UART ] CPU mandó: CR (enter)");
      else
        $display("[UART ] CPU mandó: 0x%02h (no imprimible)", rxchar);
    end
  end

  // ── Programa principal ─────────────────────────────────────
  initial begin
    $display("==============================================");
    $display("  INICIO DE SIMULACION");
    $display("==============================================");

    reset_dut();

    // ── Diagnóstico 1: verificar señales básicas ──────────────
    $display("");
    $display("---- DIAGNOSTICO POST-RESET ----");
    $display("[DEBUG] rst_i     = %b  (debe ser 0)", rst_i);
    $display("[DEBUG] clk_i     = %b  (debe oscilar)", clk_i);
    $display("[DEBUG] clk(PLL)  = %b  (debe ser igual a clk_i en sim)", dut.clk);
    $display("[DEBUG] resetn CPU= %b  (debe ser 1 para correr)", ~rst_i);

    // ── Diagnóstico 2: verificar que el .hex cargó ────────────
    $display("");
    $display("---- CONTENIDO DE LA ROM ----");
    $display("[ROM]  [0x000] = 0x%08h", {dut.u_rom.mem[3],
                                          dut.u_rom.mem[2],
                                          dut.u_rom.mem[1],
                                          dut.u_rom.mem[0]});
    $display("[ROM]  [0x004] = 0x%08h", {dut.u_rom.mem[7],
                                          dut.u_rom.mem[6],
                                          dut.u_rom.mem[5],
                                          dut.u_rom.mem[4]});
    $display("[ROM]  [0x008] = 0x%08h", {dut.u_rom.mem[11],
                                          dut.u_rom.mem[10],
                                          dut.u_rom.mem[9],
                                          dut.u_rom.mem[8]});
    $display("[ROM]  [0x00C] = 0x%08h", {dut.u_rom.mem[15],
                                          dut.u_rom.mem[14],
                                          dut.u_rom.mem[13],
                                          dut.u_rom.mem[12]});
    $display("[ROM]  Si todos son 00000000 o xxxxxxxx: el .hex no cargó");
    $display("[ROM]  Ruta actual del .hex: C:/lab2/sw/programa.hex");

    // ── Diagnóstico 3: verificar mem_valid después de unos ciclos
    $display("");
    $display("---- ACTIVIDAD DEL CPU (primeros 100 ciclos) ----");
    repeat (100) @(posedge clk_i);
    $display("[DEBUG] mem_valid = %b  (debe ser 1 si el CPU está corriendo)",
             dut.mem_valid);
    $display("[DEBUG] mem_addr  = 0x%08h  (debe ser cerca de 0x00000000)",
             dut.mem_addr);
    $display("[DEBUG] mem_ready = %b", dut.mem_ready);

    // ── Esperar arranque y mandar test ────────────────────────
    $display("");
    $display("---- ESPERANDO ARRANQUE (3000 ciclos) ----");
    repeat (3000) @(posedge clk_i);

    $display("");
    $display("---- ENVIANDO: 12+3 <ENTER> ----");
    uart_send_byte("1");
    uart_send_byte("2");
    uart_send_byte("+");
    uart_send_byte("3");
    uart_send_byte(8'h0D);
    uart_send_byte(8'h0A);

    $display("[TEST ] Esperando respuesta...");
    repeat (500000) @(posedge clk_i);

    $display("");
    $display("==============================================");
    $display("  FIN DE SIMULACION");
    $display("==============================================");
    $finish;
  end

endmodule

// ── Modelos falsos para simulación ────────────────────────────

module pll (
  input  logic clk_in,
  output logic clk_out
);
  assign clk_out = clk_in;
endmodule

module rom_programa (
  input  logic        clka,
  input  logic [8:0]  addra,
  output logic [31:0] douta
);
  reg [7:0] mem [0:2047];
  integer i;
  initial begin
    for (i = 0; i < 2048; i++) mem[i] = 8'h00;
    $readmemh("DIRECCION DEL programa.hex", mem); // <-- ajustá esta ruta
  end
  always_ff @(posedge clka)
    douta <= { mem[{addra,2'b00}+3],
               mem[{addra,2'b00}+2],
               mem[{addra,2'b00}+1],
               mem[{addra,2'b00}+0] };
endmodule

module ram_datos (
  input  logic        clka,
  input  logic [14:0] addra,
  input  logic [31:0] dina,
  output logic [31:0] douta,
  input  logic [3:0]  wea
);
  reg [31:0] mem [0:25599];
  integer i;
  initial begin
    for (i = 0; i < 25600; i++) mem[i] = 32'h00000000;
  end
  always_ff @(posedge clka) begin
    if (wea[0]) mem[addra][ 7: 0] <= dina[ 7: 0];
    if (wea[1]) mem[addra][15: 8] <= dina[15: 8];
    if (wea[2]) mem[addra][23:16] <= dina[23:16];
    if (wea[3]) mem[addra][31:24] <= dina[31:24];
    douta <= mem[addra];
  end
endmodule
