//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
// This file contains the UART Receiver.  This receiver is able to
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete o_rx_dv will be
// driven high for one clock cycle.
// 
//Adaptado por IA a SystemVerilog

// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
// uart_rx.sv — Receptor UART, 8N1
module uart_rx #(
    parameter int CLKS_PER_BIT = 10417
)(
    input  logic       i_Clock,
    input  logic       i_Rx_Serial,
    output logic       o_Rx_DV,       // Data Valid: pulso 1 ciclo al terminar
    output logic [7:0] o_Rx_Byte
);

    typedef enum logic [2:0] {
        s_IDLE         = 3'd0,
        s_RX_START_BIT = 3'd1,
        s_RX_DATA_BITS = 3'd2,
        s_RX_STOP_BIT  = 3'd3,
        s_CLEANUP      = 3'd4
    } state_t;

    // Doble registro para eliminar metaestabilidad
    logic          r_Rx_Data_R   = 1'b1;
    logic          r_Rx_Data     = 1'b1;

    logic [13:0]   r_Clock_Count = '0;
    logic [2:0]    r_Bit_Index   = '0;
    logic [7:0]    r_Rx_Byte     = '0;
    logic          r_Rx_DV       = 1'b0;
    state_t        r_SM_Main     = s_IDLE;

    // Sincronizador de 2 etapas
    always_ff @(posedge i_Clock) begin
        r_Rx_Data_R <= i_Rx_Serial;
        r_Rx_Data   <= r_Rx_Data_R;
    end

    always_ff @(posedge i_Clock) begin
        case (r_SM_Main)

            s_IDLE: begin
                r_Rx_DV       <= 1'b0;
                r_Clock_Count <= '0;
                r_Bit_Index   <= '0;
                if (r_Rx_Data == 1'b0)       // Detecta start bit
                    r_SM_Main <= s_RX_START_BIT;
            end

            s_RX_START_BIT: begin
                // Muestrea al centro del start bit
                if (r_Clock_Count == (CLKS_PER_BIT - 1) / 2) begin
                    if (r_Rx_Data == 1'b0) begin
                        r_Clock_Count <= '0;
                        r_SM_Main     <= s_RX_DATA_BITS;
                    end else
                        r_SM_Main <= s_IDLE;
                end else
                    r_Clock_Count <= r_Clock_Count + 1;
            end

            s_RX_DATA_BITS: begin
                if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Clock_Count              <= '0;
                    r_Rx_Byte[r_Bit_Index]     <= r_Rx_Data;
                    if (r_Bit_Index < 7)
                        r_Bit_Index <= r_Bit_Index + 1;
                    else begin
                        r_Bit_Index <= '0;
                        r_SM_Main   <= s_RX_STOP_BIT;
                    end
                end
            end

            s_RX_STOP_BIT: begin
                if (r_Clock_Count < CLKS_PER_BIT - 1)
                    r_Clock_Count <= r_Clock_Count + 1;
                else begin
                    r_Rx_DV       <= 1'b1;
                    r_Clock_Count <= '0;
                    r_SM_Main     <= s_CLEANUP;
                end
            end

            s_CLEANUP: begin
                r_SM_Main <= s_IDLE;
                r_Rx_DV   <= 1'b0;
            end

            default: r_SM_Main <= s_IDLE;
        endcase
    end

    assign o_Rx_DV   = r_Rx_DV;
    assign o_Rx_Byte = r_Rx_Byte;

endmodule
