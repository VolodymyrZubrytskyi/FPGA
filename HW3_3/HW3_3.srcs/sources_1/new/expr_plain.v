`timescale 1ns / 1ps

module expr_plain (
    input  wire        clk,
    input  wire        rst,       
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [7:0]  c,
    input  wire [7:0]  d,
    output reg  [25:0] result
);

    reg [7:0] a_reg, b_reg, c_reg, d_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            c_reg <= 8'd0;
            d_reg <= 8'd0;
        end else begin
            a_reg <= a;
            b_reg <= b;
            c_reg <= c;
            d_reg <= d;
        end
    end

    wire [16:0] sum_prod = a_reg * b_reg + c_reg * d_reg;   
    wire [8:0]  sum_ad   = a_reg + d_reg;                  

    always @(posedge clk or posedge rst) begin
        if (rst)
            result <= 26'd0;
        else
            result <= sum_prod * sum_ad;                    
    end

endmodule