`timescale 1ns / 1ps

module tb_led_runner_mb;

    reg         sys_clock = 1'b0;
    reg         reset     = 1'b1;
    reg  [3:0]  push_buttons_4bits_tri_i  = 4'b0000;
    reg  [15:0] dip_switches_16bits_tri_i = 16'h0000;
    wire [15:0] led_16bits_tri_o;
    reg         usb_uart_rxd = 1'b1;
    wire        usb_uart_txd;

    localparam BTN_FASTER = 4'b0001;
    localparam BTN_RUN    = 4'b0010;
    localparam BTN_HOME   = 4'b0100;
    localparam BTN_SLOWER = 4'b1000;

    led_runner_mb_wrapper dut (
        .sys_clock                 (sys_clock),
        .reset                     (reset),
        .push_buttons_4bits_tri_i  (push_buttons_4bits_tri_i),
        .dip_switches_16bits_tri_i (dip_switches_16bits_tri_i),
        .led_16bits_tri_o          (led_16bits_tri_o),
        .usb_uart_rxd              (usb_uart_rxd),
        .usb_uart_txd              (usb_uart_txd)
    );

    always #5 sys_clock = ~sys_clock;

    task press(input [3:0] mask);
    begin
        push_buttons_4bits_tri_i = mask;
        #50_000;
        push_buttons_4bits_tri_i = 4'b0000;
        #50_000;
    end
    endtask

    always @(led_16bits_tri_o)
        $display("[%0t ns] led = %b", $time, led_16bits_tri_o[3:0]);

    initial begin
        reset = 1'b1;
        #1_000;
        reset = 1'b0;

        #300_000;
        $display("[%0t ns] === running forward ===", $time);
        #120_000;

        $display("[%0t ns] === SW0 = 1: running backward ===", $time);
        dip_switches_16bits_tri_i[0] = 1'b1;
        #120_000;

        $display("[%0t ns] === BTNL: pause ===", $time);
        press(BTN_RUN);
        #100_000;

        $display("[%0t ns] === BTNL: resume ===", $time);
        press(BTN_RUN);
        #100_000;

        $display("[%0t ns] === BTNU: faster ===", $time);
        press(BTN_FASTER);
        #100_000;

        $display("[%0t ns] === BTNR: back to LD0 ===", $time);
        press(BTN_HOME);
        #60_000;

        $display("[%0t ns] simulation finished", $time);
        $finish;
    end

    initial begin
        #3_000_000;
        $display("[%0t ns] timeout", $time);
        $finish;
    end

endmodule