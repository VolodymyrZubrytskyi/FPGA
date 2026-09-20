`timescale 1ns / 1ps

module debounce #(
    parameter integer DEBOUNCE_CYCLES = 2_000_000   // 20 ms @ 100 MHz
)(
    input  wire clk,
    input  wire rst,        
    input  wire noisy_in,
    output reg  clean_out
);

    localparam integer         CNT_W   = $clog2(DEBOUNCE_CYCLES);
    localparam [CNT_W-1:0]     CNT_MAX = DEBOUNCE_CYCLES - 1;

    reg sync1, sync2;
    reg [CNT_W-1:0] cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= noisy_in;
            sync2 <= sync1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt       <= {CNT_W{1'b0}};
            clean_out <= 1'b0;
        end else if (sync2 == clean_out) begin
            cnt       <= {CNT_W{1'b0}};       
        end else if (cnt == CNT_MAX) begin
            clean_out <= sync2;               
            cnt       <= {CNT_W{1'b0}};
        end else begin
            cnt       <= cnt + 1'b1;          
        end
    end

endmodule