`timescale 1ns/1ps

module tb_top;

  
  // Parametros
  
  localparam int CLK_PERIOD_NS = 10;   
  localparam int CLKS_PER_BIT  = 87;   
  localparam int BIT_TIME_NS   = CLKS_PER_BIT * CLK_PERIOD_NS;

  
  // Señales DUT
  
  logic        clk_i;
  logic        rst_i;
  logic        uart_rx_i;
  logic        uart_tx_o;
  logic [15:0] leds_o;
  logic [15:0] sw_i;

  // DUT
 
  top dut (
    .clk_i     (clk_i),
    .rst_i     (rst_i),
    .uart_rx_i (uart_rx_i),
    .uart_tx_o (uart_tx_o),
    .leds_o    (leds_o),
    .sw_i      (sw_i)
  );

  // Clock

  initial clk_i = 1'b0;
  always #(CLK_PERIOD_NS/2) clk_i = ~clk_i;


  // Helpers

  task automatic reset_dut;
    begin
      rst_i     = 1'b1;
      uart_rx_i = 1'b1;   
      sw_i      = 16'h0000;

      repeat (20) @(posedge clk_i);
      rst_i = 1'b0;
      repeat (20) @(posedge clk_i);
    end
  endtask

  
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

  task automatic uart_send_string;
    input reg [8*64-1:0] str;
    integer idx;
    reg [7:0] ch;
    begin
      for (idx = 63; idx >= 0; idx--) begin
        ch = str[idx*8 +: 8];
        if (ch != 8'h00)
          uart_send_byte(ch);
      end
    end
  endtask

  // Monitor

  logic [15:0] leds_prev;
  initial leds_prev = 16'hxxxx;

  always @(leds_o) begin
    $display("[%0t ns] LEDs = 0x%04h", $time, leds_o);
  end

  // Monitorear accesos del CPU al bus
  always @(posedge dut.clk) begin
    if (dut.mem_valid && dut.mem_ready) begin
      if (dut.mem_wstrb != 4'b0000) begin
        $display("[%0t ns] CPU WRITE addr=0x%08h data=0x%08h wstrb=%b",
                 $time, dut.mem_addr, dut.mem_wdata, dut.mem_wstrb);
      end else begin
        $display("[%0t ns] CPU READ  addr=0x%08h data=0x%08h",
                 $time, dut.mem_addr, dut.mem_rdata);
      end
    end
  end

  // Decoder sencillo de UART TX

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

  task automatic uart_expect_activity(input integer nbytes, input integer timeout_cycles);
    integer k;
    integer t;
    reg [7:0] rxchar;
    begin
      fork
        begin : CAPTURE_BLOCK
          for (k = 0; k < nbytes; k++) begin
            uart_capture_byte(rxchar);
            if (rxchar >= 8'd32 && rxchar <= 8'd126)
              $display("[%0t ns] UART TX byte = 0x%02h ('%s')", $time, rxchar, rxchar);
            else if (rxchar == 8'h0A)
              $display("[%0t ns] UART TX byte = 0x0A (LF)", $time);
            else if (rxchar == 8'h0D)
              $display("[%0t ns] UART TX byte = 0x0D (CR)", $time);
            else
              $display("[%0t ns] UART TX byte = 0x%02h", $time, rxchar);
          end
        end
        begin : TIMEOUT_BLOCK
          for (t = 0; t < timeout_cycles; t++) @(posedge clk_i);
          $display("[%0t ns] TIMEOUT esperando actividad UART TX", $time);
          disable CAPTURE_BLOCK;
        end
      join_any
      disable fork;
    end
  endtask

  // Test principal
  initial begin
    $display("==== INICIO DE SIMULACION ====");
    reset_dut();

    sw_i = 16'h00A5;

    repeat (3000) @(posedge clk_i);
    $display("==== Enviando expresion UART: 12+3<ENTER> ====");
    uart_send_byte("1");
    uart_send_byte("2");
    uart_send_byte("+");
    uart_send_byte("3");
    uart_send_byte(8'h0D); 
    uart_send_byte(8'h0A); 

  
    uart_expect_activity(16, 300000);

    repeat (10000) @(posedge clk_i);

    $display("==== FIN DE SIMULACION ====");
    $finish;
  end

endmodule




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
    $readmemh("programa.hex", mem);
  end

  always_ff @(posedge clka) begin
    douta <= {mem[{addra,2'b00}+3],
              mem[{addra,2'b00}+2],
              mem[{addra,2'b00}+1],
              mem[{addra,2'b00}+0]};
  end
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
    if (wea[0]) mem[addra][7:0]   <= dina[7:0];
    if (wea[1]) mem[addra][15:8]  <= dina[15:8];
    if (wea[2]) mem[addra][23:16] <= dina[23:16];
    if (wea[3]) mem[addra][31:24] <= dina[31:24];
    douta <= mem[addra];
  end
endmodule
