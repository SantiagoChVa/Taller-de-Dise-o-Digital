//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
//Adaptado por IA a SystemVerilog
// This testbench will exercise both the UART Tx and Rx.
// It sends out byte 0xAB over the transmitter
// It then exercises the receive by receiving byte 0x3F
`timescale 1ns/10ps

module uart_tb ();

  // Testbench usa reloj de 10 MHz → 115200 baud
  localparam int c_CLOCK_PERIOD_NS = 100;
  localparam int c_CLKS_PER_BIT    = 87;
  localparam int c_BIT_PERIOD      = 8600;

  logic        r_Clock      = 1'b0;
  logic        r_Tx_DV      = 1'b0;
  logic [7:0]  r_Tx_Byte    = '0;
  logic        r_Rx_Serial  = 1'b1;
  logic        w_Tx_Done;
  logic [7:0]  w_Rx_Byte;

  // ── Tarea: serializa un byte hacia el RX ──────────────────────────────
  task automatic UART_WRITE_BYTE(input logic [7:0] i_Data);
    // Start bit
    r_Rx_Serial <= 1'b0;
    #(c_BIT_PERIOD);
    #1000;

    // 8 bits de datos (LSB primero)
    for (int ii = 0; ii < 8; ii++) begin
      r_Rx_Serial <= i_Data[ii];
      #(c_BIT_PERIOD);
    end

    // Stop bit
    r_Rx_Serial <= 1'b1;
    #(c_BIT_PERIOD);
  endtask

  // ── Instancias ────────────────────────────────────────────────────────
  uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST (
    .i_Clock     (r_Clock),
    .i_Rx_Serial (r_Rx_Serial),
    .o_Rx_DV     (),
    .o_Rx_Byte   (w_Rx_Byte)
  );

  uart_tx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_TX_INST (
    .i_Clock     (r_Clock),
    .i_Tx_DV     (r_Tx_DV),
    .i_Tx_Byte   (r_Tx_Byte),
    .o_Tx_Active (),
    .o_Tx_Serial (),
    .o_Tx_Done   (w_Tx_Done)
  );

  // ── Generador de reloj ────────────────────────────────────────────────
  always #(c_CLOCK_PERIOD_NS / 2) r_Clock <= ~r_Clock;

  // ── Test principal ────────────────────────────────────────────────────
  initial begin
    // Ejercitar TX: enviar 0xAB
    @(posedge r_Clock);
    @(posedge r_Clock);
    r_Tx_DV   <= 1'b1;
    r_Tx_Byte <= 8'hAB;
    @(posedge r_Clock);
    r_Tx_DV   <= 1'b0;
    @(posedge w_Tx_Done);

    // Ejercitar RX: recibir 0x3F
    @(posedge r_Clock);
    UART_WRITE_BYTE(8'h3F);
    @(posedge r_Clock);

    // Verificar byte recibido
    if (w_Rx_Byte == 8'h3F)
      $display("Test Passed - Correct Byte Received");
    else
      $display("Test Failed - Incorrect Byte Received");

    $finish;
  end

endmodule
