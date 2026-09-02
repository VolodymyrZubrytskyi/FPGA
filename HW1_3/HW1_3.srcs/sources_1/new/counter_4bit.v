`timescale 1ns / 1ps

module counter_4bit(
    input clk,
    input reset,
    output reg [3:0] out 
    );
        
    always @(posedge clk or posedge reset) begin
        if(reset == 0) begin
            out <= out + 1;
        end
        else begin
            out <= 4'b0000;
        end         
    end
endmodule
