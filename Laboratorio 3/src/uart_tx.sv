//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
//Adaptado por IA a SystemVerilog

// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87



// uart_tx.sv — Transmisor UART, 8N1
// CLKS_PER_BIT = f_clk / baud_rate  (100e6/9600 = 10417)
module uart_tx #(
    parameter int CLKS_PER_BIT = 10417
)(
    input  logic       i_Clock,
    input  logic       i_Tx_DV,      // Data Valid: pulso 1 ciclo para iniciar TX
    input  logic [7:0] i_Tx_Byte,
    output logic       o_Tx_Active,
    output logic       o_Tx_Serial,
    output logic       o_Tx_Done
);

    typedef enum logic [2:0] {
        s_IDLE         = 3'd0,
        s_TX_START_BIT = 3'd1,
        s_TX_DATA_BITS = 3'd2,
        s_TX_STOP_BIT  = 3'd3,
        s_CLEANUP      = 3'd4
    } state_t;

    state_t        r_SM_Main     = s_IDLE;
    logic [13:0]   r_Clock_Count = '0;   // 14 bits para 10417
    logic [2:0]    r_Bit_Index   = '0;
    logic [7:0]    r_Tx_Data     = '0;
    logic          r_Tx_Done     = 1'b0;
    logic          r_Tx_Active   = 1'b0;

    always_ff @(posedge i_Clock) begin
        case (r_SM_Main)

            s_IDLE: begin
                o_Tx_Serial   <= 1'b1;
                r_Tx_Done     <= 1'b0;
                r_Clock_Count <= '0;
                r_Bit_Index   <= '0;
                if (i_Tx_DV) begin
                    r_Tx_Active <= 1'b1;
                    r_Tx_Data   <= i_Tx_Byte;
                    r_SM_Main   <= s_TX_START_BIT;
                end
            end

            s_TX_START_BIT: begin
                o_Tx_Serial <= 1'b0;
                if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Clock_Count <= '0;
                    r_SM_Main     <= s_TX_DATA_BITS;
                end
            end

            s_TX_DATA_BITS: begin
                o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
                if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Clock_Count <= '0;
                    if (r_Bit_Index < 7) begin
                        r_Bit_Index <= r_Bit_Index + 1;
                    end else begin
                        r_Bit_Index <= '0;
                        r_SM_Main   <= s_TX_STOP_BIT;
                    end
                end
            end

            s_TX_STOP_BIT: begin
                o_Tx_Serial <= 1'b1;
                if (r_Clock_Count < CLKS_PER_BIT - 1) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                end else begin
                    r_Tx_Done     <= 1'b1;
                    r_Clock_Count <= '0;
                    r_Tx_Active   <= 1'b0;
                    r_SM_Main     <= s_CLEANUP;
                end
            end

            s_CLEANUP: begin
                r_Tx_Done <= 1'b1;
                r_SM_Main <= s_IDLE;
            end

            default: r_SM_Main <= s_IDLE;
        endcase
    end

    assign o_Tx_Active = r_Tx_Active;
    assign o_Tx_Done   = r_Tx_Done;

endmodule