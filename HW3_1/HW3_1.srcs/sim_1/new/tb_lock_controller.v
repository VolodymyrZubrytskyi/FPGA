`timescale 1ns / 1ps

module tb_lock_controller;

    reg        clk = 0;
    reg        rst = 0;
    reg  [3:0] digit_in = 0;
    wire       unlocked_led;

    always #5 clk = ~clk;

    lock_controller uut (
        .clk          (clk),
        .rst          (rst),
        .digit_in     (digit_in),
        .unlocked_led (unlocked_led)
    );

    // ---------- HELPER TASKS ----------

    task press(input [3:0] d);
    begin
        digit_in = d;      
        @(posedge clk);    
        @(negedge clk);    
    end
    endtask

    task expect_state(input [2:0] exp, input [8*16-1:0] name);
    begin
        if (uut.state !== exp)
            $display("FAIL at %0t: expected %0s, got %0d", $time, name, uut.state);
        else
            $display("OK   at %0t: %0s", $time, name);
    end
    endtask

    // ---------- TEST SCENARIOS ----------

    initial begin
        rst = 1;
        #12 rst = 0;
        expect_state(uut.LOCKED, "LOCKED after reset");

        // --- 1. correct sequence: 5 -> 3 -> 7, one transition per step
        press(4'd5); expect_state(uut.WAIT_D2,  "LOCKED  -> WAIT_D2");
        press(4'd3); expect_state(uut.WAIT_D3,  "WAIT_D2 -> WAIT_D3");
        press(4'd7); expect_state(uut.UNLOCKED, "WAIT_D3 -> UNLOCKED");

        if (unlocked_led !== 1'b1)
            $display("FAIL at %0t: unlocked_led not set", $time);
        else
            $display("OK   at %0t: unlocked_led = 1", $time);

        // --- 2. UNLOCKED holds on any further input
        press(4'd0); expect_state(uut.UNLOCKED, "UNLOCKED holds");

        // --- 3. only reset leaves UNLOCKED (also checks async reset)
        rst = 1;
        #12 rst = 0;
        expect_state(uut.LOCKED, "LOCKED after reset from UNLOCKED");

        if (unlocked_led !== 1'b0)
            $display("FAIL at %0t: unlocked_led not cleared", $time);

        // --- 4. error scenarios: wrong digit at each step returns to LOCKED
        press(4'd9);
        expect_state(uut.LOCKED, "wrong 1st digit -> LOCKED");

        press(4'd5); press(4'd9);
        expect_state(uut.LOCKED, "wrong 2nd digit -> LOCKED");

        press(4'd5); press(4'd3); press(4'd9);
        expect_state(uut.LOCKED, "wrong 3rd digit -> LOCKED");

        // --- 5. lock still works after an error
        press(4'd5); press(4'd3); press(4'd7);
        expect_state(uut.UNLOCKED, "correct sequence after error");

        $display("done");
        $finish;
    end

endmodule