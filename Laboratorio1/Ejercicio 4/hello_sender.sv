module hello_sender #(
    parameter int CLKS_PER_BIT   = 10417,
    parameter int DEBOUNCE_LIMIT = 500_000
)(
    input  logic CLK100MHZ,
    input  logic BTNC,
    output logic UART_RXD_OUT
);

    // ── Mensaje ─────────────────────────────────────────────────────────
    localparam int MSG_LEN = 12;
    logic [7:0] msg [0:MSG_LEN-1];
    initial begin
        msg[0]  = 8'h48; // H
        msg[1]  = 8'h6F; // o
        msg[2]  = 8'h6C; // l
        msg[3]  = 8'h61; // a
        msg[4]  = 8'h20; // (space)
        msg[5]  = 8'h6D; // m
        msg[6]  = 8'h75; // u
        msg[7]  = 8'h6E; // n
        msg[8]  = 8'h64; // d
        msg[9]  = 8'h6F; // o
        msg[10] = 8'h0D; // \r
        msg[11] = 8'h0A; // \n
    end

    // ── Debounce ─────────────────────────────────────────────────────────
    logic [19:0] r_Debounce_Cnt = '0;
    logic        r_Btn_Prev     = 1'b0;
    logic        r_Btn_Clean    = 1'b0;
    logic        w_Btn_Pulse;

    always_ff @(posedge CLK100MHZ) begin
        if (BTNC == r_Btn_Clean) begin
            r_Debounce_Cnt <= '0;
        end else begin
            if (r_Debounce_Cnt == DEBOUNCE_LIMIT - 1) begin
                r_Btn_Clean    <= BTNC;
                r_Debounce_Cnt <= '0;
            end else
                r_Debounce_Cnt <= r_Debounce_Cnt + 1;
        end
        r_Btn_Prev <= r_Btn_Clean;
    end

    assign w_Btn_Pulse = r_Btn_Clean & ~r_Btn_Prev;

    // ── Interfaz con uart_tx ─────────────────────────────────────────────
    logic       r_Tx_DV   = 1'b0;
    logic [7:0] r_Tx_Byte = '0;
    logic       w_Tx_Done;
    logic       w_Tx_Active;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .i_Clock     (CLK100MHZ),
        .i_Tx_DV     (r_Tx_DV),
        .i_Tx_Byte   (r_Tx_Byte),
        .o_Tx_Active (w_Tx_Active),
        .o_Tx_Serial (UART_RXD_OUT),
        .o_Tx_Done   (w_Tx_Done)
    );

    // ── FSM del sender ───────────────────────────────────────────────────
    typedef enum logic [1:0] {
        ST_IDLE = 2'd0,
        ST_LOAD = 2'd1,
        ST_WAIT = 2'd2
    } fsm_t;

    fsm_t       r_State = ST_IDLE;
    logic [3:0] r_Idx   = '0;

    always_ff @(posedge CLK100MHZ) begin
        r_Tx_DV <= 1'b0;

        case (r_State)
            ST_IDLE: begin
                if (w_Btn_Pulse) begin
                    r_Idx   <= '0;
                    r_State <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                r_Tx_Byte <= msg[r_Idx];
                r_Tx_DV   <= 1'b1;
                r_State   <= ST_WAIT;
            end

            ST_WAIT: begin
                if (w_Tx_Done) begin
                    if (r_Idx == MSG_LEN - 1)
                        r_State <= ST_IDLE;
                    else begin
                        r_Idx   <= r_Idx + 1;
                        r_State <= ST_LOAD;
                    end
                end
            end

            default: r_State <= ST_IDLE;
        endcase
    end

endmodule
