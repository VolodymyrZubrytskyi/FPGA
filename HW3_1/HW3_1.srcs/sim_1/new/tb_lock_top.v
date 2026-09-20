`timescale 1ns / 1ps

module tb_lock_top;

    localparam integer N    = 10;
    localparam integer LAT  = N + 2;      
    localparam integer HOLD = LAT + 5;    

    reg        clk = 0;
    reg        rst = 0;
    reg  [3:0] btn = 4'd0;
    wire       led;

    always #5 clk = ~clk;

    lock_top #(.DEBOUNCE_CYCLES(N)) uut (
        .clk (clk),
        .rst (rst),
        .btn (btn),
        .led (led)
    );

    // ---------- HELPER TASKS ----------

    task wait_cycles(input integer n);
    begin
        repeat (n) @(posedge clk);
        @(negedge clk);
    end
    endtask

    task press(input [3:0] d);
    begin
        btn = d;
        wait_cycles(HOLD);
        btn = 4'd0;
        wait_cycles(HOLD);
    end
    endtask

    task expect_state(input [1:0] exp, input [8*40-1:0] name);
    begin
        if (uut.u_lock.state !== exp)
            $display("FAIL at %0t: %0s: expected %0d, got %0d",
                     $time, name, exp, uut.u_lock.state);
        else
            $display("OK   at %0t: %0s", $time, name);
    end
    endtask

    // ---------- TEST SCENARIOS ----------

    initial begin
        // 1. reset
        rst = 1;
        #12 rst = 0;
        @(negedge clk);
        expect_state(uut.u_lock.LOCKED, "LOCKED after reset");

        // 2. correct sequence, one physical press per digit
        press(4'd5); expect_state(uut.u_lock.WAIT_D2,  "LOCKED  -> WAIT_D2");
        press(4'd3); expect_state(uut.u_lock.WAIT_D3,  "WAIT_D2 -> WAIT_D3");
        press(4'd7); expect_state(uut.u_lock.UNLOCKED, "WAIT_D3 -> UNLOCKED");

        if (led !== 1'b1)
            $display("FAIL at %0t: led not set", $time);
        else
            $display("OK   at %0t: led = 1", $time);

        // 3. UNLOCKED holds on further presses
        press(4'd9); expect_state(uut.u_lock.UNLOCKED, "UNLOCKED holds");

        // 4. only reset leaves UNLOCKED
        rst = 1;
        #12 rst = 0;
        @(negedge clk);
        expect_state(uut.u_lock.LOCKED, "LOCKED after reset from UNLOCKED");
        if (led !== 1'b0)
            $display("FAIL at %0t: led not cleared", $time);

        // 5. wrong digit at each step
        press(4'd9);
        expect_state(uut.u_lock.LOCKED, "wrong 1st digit -> LOCKED");

        press(4'd5); press(4'd9);
        expect_state(uut.u_lock.LOCKED, "wrong 2nd digit -> LOCKED");

        press(4'd5); press(4'd3); press(4'd9);
        expect_state(uut.u_lock.LOCKED, "wrong 3rd digit -> LOCKED");

        // 6. the key check: a long hold enters the digit exactly once
        btn = 4'd5;
        wait_cycles(100);
        expect_state(uut.u_lock.WAIT_D2, "long hold of 5: still WAIT_D2");
        btn = 4'd0;
        wait_cycles(HOLD);
        expect_state(uut.u_lock.WAIT_D2, "release after long hold: still WAIT_D2");

        // 7. sequence completes after the long hold
        press(4'd3); expect_state(uut.u_lock.WAIT_D3,  "WAIT_D2 -> WAIT_D3");
        press(4'd7); expect_state(uut.u_lock.UNLOCKED, "WAIT_D3 -> UNLOCKED");

        // 8. a press shorter than the debounce window is ignored
        rst = 1;
        #12 rst = 0;
        @(negedge clk);
        btn = 4'd5;
        wait_cycles(N - 1);
        btn = 4'd0;
        wait_cycles(HOLD);
        expect_state(uut.u_lock.LOCKED, "short press filtered: still LOCKED");

        $display("done");
        $finish;
    end

endmodule