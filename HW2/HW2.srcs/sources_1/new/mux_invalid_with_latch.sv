`timescale 1ns / 1ps

module mux_invalid_with_latch(
    input logic [1:0] in,
    input logic sel,
    output logic out
    );

    always_comb begin
       case(sel)
        1'b0:
            out = in[0];
        endcase        
    end
endmodule
