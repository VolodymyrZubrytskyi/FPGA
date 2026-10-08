`timescale 1ns / 1ps

module tb_design_1_wrapper;

    localparam integer FRAME_WORDS = 64;
    localparam integer FRAME_BYTES = FRAME_WORDS * 4;

    localparam BOOT_WAIT = 300_000;
    localparam ARM_WAIT  =  50_000;
    localparam DONE_WAIT = 150_000;

    reg         sys_clock = 1'b0;
    reg         reset     = 1'b1;
    reg  [3:0]  push_buttons_4bits_tri_i = 4'b0000;

    reg         pix_clk_0   = 1'b0;
    reg         pix_rst_0   = 1'b1;
    reg  [7:0]  pix_data_0  = 8'h00;
    reg         pix_valid_0 = 1'b0;

    reg         usb_uart_rxd = 1'b1;
    wire        usb_uart_txd;

    integer i;
    integer errors = 0;
    reg [31:0] got, exp;

    design_1_wrapper dut (
        .sys_clock                (sys_clock),
        .reset                    (reset),
        .push_buttons_4bits_tri_i (push_buttons_4bits_tri_i),
        .pix_clk_0                (pix_clk_0),
        .pix_rst_0                (pix_rst_0),
        .pix_data_0               (pix_data_0),
        .pix_valid_0              (pix_valid_0),
        .usb_uart_rxd             (usb_uart_rxd),
        .usb_uart_txd             (usb_uart_txd)
    );

    always #5    sys_clock = ~sys_clock;
    always #12.5 pix_clk_0 = ~pix_clk_0;

    task send_frame;
        integer k;
    begin
        for (k = 0; k < FRAME_BYTES; k = k + 1) begin
            @(negedge pix_clk_0);
            pix_data_0  = k[7:0];
            pix_valid_0 = 1'b1;
        end
        @(negedge pix_clk_0);
        pix_valid_0 = 1'b0;
    end
    endtask

    function [31:0] expected(input integer k);
        reg [7:0] b0, b1, b2, b3;
    begin
        b0 = (4*k + 0);
        b1 = (4*k + 1);
        b2 = (4*k + 2);
        b3 = (4*k + 3);
        expected = {b3, b2, b1, b0};
    end
    endfunction

    initial begin
        reset       = 1'b1;
        pix_rst_0   = 1'b1;
        #1_000;
        reset       = 1'b0;
        pix_rst_0   = 1'b0;
        $display("[%0t ns] reset released", $time);

        #BOOT_WAIT;
        $display("[%0t ns] pressing button", $time);
        push_buttons_4bits_tri_i = 4'b0001;
        #2_000;
        push_buttons_4bits_tri_i = 4'b0000;

        #ARM_WAIT;
        $display("[%0t ns] sending %0d bytes", $time, FRAME_BYTES);
        send_frame;
        $display("[%0t ns] frame sent", $time);

        #DONE_WAIT;

        for (i = 0; i < FRAME_WORDS; i = i + 1) begin
            got = dut.design_1_i.axi4_full_ram_0.inst.mem[i];
            exp = expected(i);
            if (got !== exp) begin
                errors = errors + 1;
                if (errors <= 8)
                    $display("FAIL: mem[%0d] = %h, expected %h", i, got, exp);
            end
        end

        if (errors == 0)
            $display("=== PASS: %0d words written by DMA ===", FRAME_WORDS);
        else
            $display("=== FAIL: %0d errors ===", errors);

        $finish;
    end

    initial begin
        #3_000_000;
        $display("timeout at %0t ns", $time);
        for (i = 0; i < 8; i = i + 1)
            $display("mem[%0d] = %h", i, dut.design_1_i.axi4_full_ram_0.inst.mem[i]);
        $finish;
    end

endmodule