`timescale 1ns / 1ps

module lock_controller_dbn #(
    parameter [3:0] CODE_D1 = 4'd5,
    parameter [3:0] CODE_D2 = 4'd3,
    parameter [3:0] CODE_D3 = 4'd7
)(
    input  wire       clk,
    input  wire       rst,         
    input  wire [3:0] digit_in,
    input  wire       digit_valid, 
    output reg        unlocked_led
);

    localparam [1:0] LOCKED   = 2'd0;
    localparam [1:0] WAIT_D2  = 2'd1;
    localparam [1:0] WAIT_D3  = 2'd2;
    localparam [1:0] UNLOCKED = 2'd3;

    reg [1:0] state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst) state <= LOCKED;
        else     state <= next_state;
    end

    always @(*) begin
        next_state = state;
        if (digit_valid) begin
            case (state)
                LOCKED:   next_state = (digit_in == CODE_D1) ? WAIT_D2  : LOCKED;
                WAIT_D2:  next_state = (digit_in == CODE_D2) ? WAIT_D3  : LOCKED;
                WAIT_D3:  next_state = (digit_in == CODE_D3) ? UNLOCKED : LOCKED;
                UNLOCKED: next_state = UNLOCKED;
                default:  next_state = LOCKED;
            endcase
        end
    end

    always @(*) begin
        unlocked_led = (state == UNLOCKED);
    end

endmodule