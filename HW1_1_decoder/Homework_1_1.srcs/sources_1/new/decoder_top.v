`timescale 1ns / 1ps

module decoder_top(
    input wire [1:0] in4,
    output wire [3:0] out4,
    
    input wire [2:0] in8,
    output wire [7:0] out8      
);

    decoder #(.WIDTH(4)) dec4 (.in(in4), .out(out4));
    decoder #(.WIDTH(8)) dec8 (.in(in8), .out(out8));

endmodule
