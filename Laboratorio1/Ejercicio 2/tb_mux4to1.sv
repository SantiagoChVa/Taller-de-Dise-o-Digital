`timescale 1ns / 1ps

module tb_mux4to1;

    // WIDTH = 4
    logic [3:0] in0_4, in1_4, in2_4, in3_4;
    logic [1:0] sel_4;
    logic [3:0] y_4;

    // WIDTH = 8
    logic [7:0] in0_8, in1_8, in2_8, in3_8;
    logic [1:0] sel_8;
    logic [7:0] y_8;

    // WIDTH = 16
    logic [15:0] in0_16, in1_16, in2_16, in3_16;
    logic [1:0] sel_16;
    logic [15:0] y_16;

    // Instancia MUX 4 bits
    mux4to1 #(.WIDTH(4)) mux4 (
        .in0(in0_4),
        .in1(in1_4),
        .in2(in2_4),
        .in3(in3_4),
        .sel(sel_4),
        .y(y_4)
    );

    // Instancia MUX 8 bits
    mux4to1 #(.WIDTH(8)) mux8 (
        .in0(in0_8),
        .in1(in1_8),
        .in2(in2_8),
        .in3(in3_8),
        .sel(sel_8),
        .y(y_8)
    );

    // Instancia MUX 16 bits
    mux4to1 #(.WIDTH(16)) mux16 (
        .in0(in0_16),
        .in1(in1_16),
        .in2(in2_16),
        .in3(in3_16),
        .sel(sel_16),
        .y(y_16)
    );

    initial begin
        $srandom(1234);  

        // TEST WIDTH = 4
        repeat(50) begin
            in0_4 = $urandom;
            in1_4 = $urandom;
            in2_4 = $urandom;
            in3_4 = $urandom;

            for (int i = 0; i < 4; i++) begin
                sel_4 = i;
                #1;

                case (sel_4)
                    2'b00: if (y_4 != in0_4) $fatal(1, "Error WIDTH4 sel00");
                    2'b01: if (y_4 != in1_4) $fatal(1, "Error WIDTH4 sel01");
                    2'b10: if (y_4 != in2_4) $fatal(1, "Error WIDTH4 sel10");
                    2'b11: if (y_4 != in3_4) $fatal(1, "Error WIDTH4 sel11");
                endcase
            end
        end

        $display("WIDTH 4 OK");

        // TEST WIDTH = 8
        repeat(50) begin
            in0_8 = $urandom;
            in1_8 = $urandom;
            in2_8 = $urandom;
            in3_8 = $urandom;

            for (int i = 0; i < 4; i++) begin
                sel_8 = i;
                #1;

                case (sel_8)
                    2'b00: if (y_8 != in0_8) $fatal(1, "Error WIDTH8 sel00");
                    2'b01: if (y_8 != in1_8) $fatal(1, "Error WIDTH8 sel01");
                    2'b10: if (y_8 != in2_8) $fatal(1, "Error WIDTH8 sel10");
                    2'b11: if (y_8 != in3_8) $fatal(1, "Error WIDTH8 sel11");
                endcase
            end
        end

        $display("WIDTH 8 OK");

        // TEST WIDTH = 16
        repeat(50) begin
            in0_16 = $urandom;
            in1_16 = $urandom;
            in2_16 = $urandom;
            in3_16 = $urandom;

            for (int i = 0; i < 4; i++) begin
                sel_16 = i;
                #1;

                case (sel_16)
                    2'b00: if (y_16 != in0_16) $fatal(1, "Error WIDTH16 sel00");
                    2'b01: if (y_16 != in1_16) $fatal(1, "Error WIDTH16 sel01");
                    2'b10: if (y_16 != in2_16) $fatal(1, "Error WIDTH16 sel10");
                    2'b11: if (y_16 != in3_16) $fatal(1, "Error WIDTH16 sel11");
                endcase
            end
        end

        $display("WIDTH 16 OK");
        $display("TODAS LAS PRUEBAS PASARON");
        $finish;
    end

endmodule
