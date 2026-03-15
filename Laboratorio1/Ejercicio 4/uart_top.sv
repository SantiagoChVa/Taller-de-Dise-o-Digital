module uart_top (
    input  logic        CLK100MHZ,
    input  logic        BTNC,
    input  logic        UART_TXD_IN,
    output logic        UART_RXD_OUT,
    output logic [15:0] LED
);

    localparam int CLKS_PER_BIT = 10417;

    logic r_Btn_R = 1'b0, r_Btn = 1'b0;
    always_ff @(posedge CLK100MHZ) begin
        r_Btn_R <= BTNC;
        r_Btn   <= r_Btn_R;
    end

    hello_sender #(
        .CLKS_PER_BIT  (CLKS_PER_BIT),
        .DEBOUNCE_LIMIT(500_000)
    ) u_sender (
        .CLK100MHZ   (CLK100MHZ),
        .BTNC        (r_Btn),        // señal ya sincronizada
        .UART_RXD_OUT(UART_RXD_OUT)
    );

    logic       w_Rx_DV;
    logic [7:0] w_Rx_Byte;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .i_Clock     (CLK100MHZ),
        .i_Rx_Serial (UART_TXD_IN),
        .o_Rx_DV     (w_Rx_DV),
        .o_Rx_Byte   (w_Rx_Byte)
    );

    always_ff @(posedge CLK100MHZ) begin
        if (w_Rx_DV)
            LED[7:0] <= w_Rx_Byte;
    end
    assign LED[15:8] = 8'b0;

endmodule
