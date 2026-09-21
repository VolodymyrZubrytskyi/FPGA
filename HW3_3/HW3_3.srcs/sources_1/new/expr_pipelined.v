`timescale 1ns / 1ps

module expr_pipelined (
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

    reg [16:0] sum_prod_reg;   // a*b + c*d
    reg [8:0]  sum_ad_reg;     // a + d 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sum_prod_reg <= 17'd0;
            sum_ad_reg   <= 9'd0;
        end else begin
            sum_prod_reg <= a_reg * b_reg + c_reg * d_reg;
            sum_ad_reg   <= a_reg + d_reg;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            result <= 26'd0;
        else
            result <= sum_prod_reg * sum_ad_reg;
    end

endmodule