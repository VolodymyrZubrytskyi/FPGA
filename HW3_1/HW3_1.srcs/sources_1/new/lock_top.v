`timescale 1ns / 1ps

module lock_top #(
    parameter integer DEBOUNCE_CYCLES = 2_000_000   // 20 ms @ 100 MHz
)(
    input  wire       clk,
    input  wire       rst,       
    input  wire [3:0] btn,       
    output wire       led
);

    wire [3:0] digit_clean;
    reg  [3:0] digit_prev;
    wire       digit_valid;

    // 1. One debounce filter per button
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : g_dbn
            debounce #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_dbn (
                .clk       (clk),
                .rst       (rst),
                .noisy_in  (btn[i]),
                .clean_out (digit_clean[i])
            );
        end
    endgenerate

    // 2. Edge detector: strobe on a new non-zero filtered digit
    always @(posedge clk or posedge rst) begin
        if (rst) digit_prev <= 4'd0;
        else     digit_prev <= digit_clean;
    end

    assign digit_valid = (digit_clean != digit_prev) && (digit_clean != 4'd0);

    // 3. Lock FSM
    lock_controller_dbn u_lock (
        .clk          (clk),
        .rst          (rst),
        .digit_in     (digit_clean),
        .digit_valid  (digit_valid),
        .unlocked_led (led)
    );

endmodule