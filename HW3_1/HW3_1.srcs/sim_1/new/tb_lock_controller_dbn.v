`timescale 1ns / 1ps

module tb_lock_controller_dbn;

    reg        clk = 0;
    reg        rst = 0;
    reg  [3:0] digit_in = 0;
    reg        digit_valid = 0;
    wire       unlocked_led;

    always #5 clk = ~clk;

    lock_controller_dbn uut (
        .clk          (clk),
        .rst          (rst),
        .digit_in     (digit_in),
        .digit_valid  (digit_valid),
        .unlocked_led (unlocked_led)
    );

    // ---------- HELPER TASKS ----------

    task press(input [3:0] d);
    begin
        digit_in    = d;
        digit_valid = 1'b1;
        @(posedge clk);       
        @(negedge clk);
        digit_valid = 1'b0;  
    end
    endtask

    task hold(input [3:0] d, input integer n);
    begin
        digit_in    = d;
        digit_valid = 1'b0;
        repeat (n) @(posedge clk);
        @(negedge clk);
    end
    endtask

    task expect_state(input [1:0] exp, input [8*32-1:0] name);
    begin
        if (uut.state !== exp)
            $display("FAIL at %0t: expected %0s, got %0d", $time, name, uut.state);
        else
            $display("OK   at %0t: %0s", $time, name);
    end
    endtask

    // ---------- TEST SCENARIOS ----------

    initial begin
        // asynchronous reset, released away from a clock edge
        rst = 1;
        #12 rst = 0;
        expect_state(uut.LOCKED, "LOCKED after reset");

        // --- 1. correct sequence, one transition per strobe
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

        // --- 5. digit_valid = 0: FSM must ignore digit_in completely
        //     a) correct digit without strobe does not advance
        hold(4'd5, 5);
        expect_state(uut.LOCKED, "no strobe: correct digit ignored");

        //     b) the trap: in WAIT_D2 a held digit must NOT reset to LOCKED
        press(4'd5); expect_state(uut.WAIT_D2, "LOCKED -> WAIT_D2");
        hold(4'd5, 5);
        expect_state(uut.WAIT_D2, "no strobe: WAIT_D2 held with stale 5");
        hold(4'd9, 5);
        expect_state(uut.WAIT_D2, "no strobe: WAIT_D2 held with wrong 9");

        //     c) sequence still completes after long holds between strobes
        press(4'd3); hold(4'd3, 20);
        expect_state(uut.WAIT_D3, "WAIT_D2 -> WAIT_D3 then held");
        press(4'd7);
        expect_state(uut.UNLOCKED, "WAIT_D3 -> UNLOCKED after holds");

        $display("done");
        $finish;
    end

endmodule