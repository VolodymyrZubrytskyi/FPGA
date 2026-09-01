`timescale 1ns / 1ps

module decoder
        #(parameter WIDTH=4) (
       input wire [$clog2(WIDTH) - 1:0] in,
       output wire [WIDTH - 1:0] out 
    );
    
    assign out = 1'b1 << in;
endmodule
