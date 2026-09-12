`timescale 1ns / 1ps

module tb_counter;

    reg clk = 0;
    reg rst;
    reg load = 0;
    reg [3:0] data_in = 0;
    reg en = 0;
    reg up_down = 0;
    wire [3:0] count;

    always #5 clk = ~clk;

    counter uut (
        .clk     (clk),
        .rst     (rst),
        .load    (load),
        .data_in (data_in),
        .en      (en),
        .up_down (up_down),
        .count   (count)
    );

    // ---------- HELPER TASKS ----------
    task automatic check_count;
        input [3:0]        expected;
        input [8*24 - 1:0] name;

        if (count === expected)
            $display("%0s: PASS", name);
        else
            $display("%0s: FAIL (expected: %0d, got %0d)", name, expected, count);
    endtask

    initial begin
        @(posedge clk); #1;
        @(posedge clk); #1;
        
        // ---------  3. LOAD ---------------
        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        load    = 1;
        data_in = 4'd10;
        @(posedge clk); #1;
        load = 0;

        check_count(10, "LOAD");

        // ---------  4. COUNT UP ---------------
        en      = 1;
        up_down = 1;

        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        check_count(13, "COUNT UP");

        @(posedge clk); #1;
        @(posedge clk); #1;
        @(posedge clk); #1;

        check_count(0, "COUNT UP WRAP 15->0");

        // ---------  5. VALUE HOLD ---------------
        en = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;

        check_count(0, "VALUE HOLD");

        // ---------  6. COUNT DOWN ---------------
        up_down = 0;
        en      = 1;
        @(posedge clk); #1;

        check_count(15, "COUNT DOWN WRAP 0->15");

        // ---------  7. LOAD OVER EN PRIORITY ---------------
        load    = 1;
        data_in = 4'd5;
        en      = 1;
        up_down = 1;
        @(posedge clk); #1;
        load = 0;

        check_count(5, "LOAD OVER EN PRIORITY");

        // ---------  BONUS. COUNT DOWN NOT EDGE ---------------
        up_down = 0;
        @(posedge clk); #1;

        check_count(4, "COUNT DOWN 5->4");

        $finish;
    end
endmodule