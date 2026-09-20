`timescale 1ns / 1ps

module tb_debounce;

    localparam integer N   = 10;
    localparam integer LAT = N + 2;

    reg  clk = 0;
    reg  rst = 0;
    reg  noisy_in = 0;
    wire clean_out;

    always #5 clk = ~clk;

    debounce #(.DEBOUNCE_CYCLES(N)) uut (
        .clk       (clk),
        .rst       (rst),
        .noisy_in  (noisy_in),
        .clean_out (clean_out)
    );

    // ---------- OBSERVER ----------
    // Counts every change of clean_out, independent of the scenarios.
    integer changes = 0;

    always @(clean_out) begin
        changes = changes + 1;
        $display("      clean_out -> %b at %0t", clean_out, $time);
    end

    // ---------- HELPER TASKS ----------

    // Wait n rising edges, then settle on the falling edge.
    task wait_cycles(input integer n);
    begin
        repeat (n) @(posedge clk);
        @(negedge clk);
    end
    endtask

    // Simulate contact bounce: 6 toggles with 2..4 cycle gaps (all < N),
    // then settle on final_val.
    task bounce(input final_val);
        integer i;
    begin
        for (i = 0; i < 6; i = i + 1) begin
            noisy_in = ~noisy_in;
            wait_cycles(2 + (i % 3));   // 2,3,4,2,3,4
        end
        noisy_in = final_val;
    end
    endtask

    task expect_out(input exp, input [8*40-1:0] name);
    begin
        if (clean_out !== exp)
            $display("FAIL at %0t: %0s: expected %b, got %b", $time, name, exp, clean_out);
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
        changes = 0;                        // ignore X -> 0 at reset
        expect_out(1'b0, "clean_out = 0 after reset");

        // 2. press with bounce: output must change once, exactly at LAT
        bounce(1'b1);
        wait_cycles(LAT - 1);
        expect_out(1'b0, "press: still 0 one cycle before LAT");
        wait_cycles(1);
        expect_out(1'b1, "press: 1 at LAT");
        if (changes !== 1) $display("FAIL: press caused %0d changes, expected 1", changes);

        // 3. hold: nothing happens while the input is stable
        wait_cycles(30);
        expect_out(1'b1, "hold: still 1 after 30 cycles");
        if (changes !== 1) $display("FAIL: hold caused extra changes (%0d)", changes);

        // 4. release with bounce
        bounce(1'b0);
        wait_cycles(LAT - 1);
        expect_out(1'b1, "release: still 1 one cycle before LAT");
        wait_cycles(1);
        expect_out(1'b0, "release: 0 at LAT");
        if (changes !== 2) $display("FAIL: release caused %0d changes total, expected 2", changes);

        // 5. short pulse (5 cycles < N): must be filtered out
        noisy_in = 1'b1;
        wait_cycles(5);
        noisy_in = 1'b0;
        wait_cycles(LAT + 5);
        expect_out(1'b0, "short pulse (5): filtered");

        // 6. boundary pulse (N-1 cycles): must still be filtered out
        noisy_in = 1'b1;
        wait_cycles(N - 1);
        noisy_in = 1'b0;
        wait_cycles(LAT + 5);
        expect_out(1'b0, "boundary pulse (N-1): filtered");

        // 7. summary
        if (changes !== 2)
            $display("FAIL: clean_out changed %0d times, expected 2", changes);
        else
            $display("OK   clean_out changed exactly 2 times");

        $display("done");
        $finish;
    end

endmodule