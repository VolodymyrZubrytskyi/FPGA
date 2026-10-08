`timescale 1ns / 1ps

module tb_frame_rx;

    localparam integer WORDS = 8;
    localparam integer BYTES = WORDS * 4;

    reg         pix_clk = 1'b0;
    reg         pix_rst = 1'b1;
    reg  [7:0]  pix_data = 8'h00;
    reg         pix_valid = 1'b0;

    reg         m_axis_aclk = 1'b0;
    reg         m_axis_aresetn = 1'b0;
    reg         start = 1'b0;
    wire        busy;

    wire [31:0] m_axis_tdata;
    wire [3:0]  m_axis_tkeep;
    wire        m_axis_tvalid;
    reg         m_axis_tready = 1'b0;
    wire        m_axis_tlast;

    integer errors = 0;
    integer rx_cnt = 0;
    integer last_at = -1;
    reg [31:0] rx_word [0:WORDS-1];

    frame_rx #(.FRAME_WORDS(WORDS), .FIFO_AW(4)) dut (
        .pix_clk        (pix_clk),
        .pix_rst        (pix_rst),
        .pix_data       (pix_data),
        .pix_valid      (pix_valid),
        .m_axis_aclk    (m_axis_aclk),
        .m_axis_aresetn (m_axis_aresetn),
        .start          (start),
        .busy           (busy),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast)
    );

    always #12.5 pix_clk     = ~pix_clk;
    always #5    m_axis_aclk = ~m_axis_aclk;

    always @(posedge m_axis_aclk)
        m_axis_tready <= (($random % 4) != 0);

    always @(posedge m_axis_aclk) begin
        if (m_axis_aresetn && m_axis_tvalid && m_axis_tready) begin
            if (rx_cnt < WORDS) rx_word[rx_cnt] = m_axis_tdata;
            if (m_axis_tlast) last_at = rx_cnt;
            if (m_axis_tkeep !== 4'hF) begin
                errors = errors + 1;
                $display("FAIL: tkeep = %b at word %0d", m_axis_tkeep, rx_cnt);
            end
            rx_cnt = rx_cnt + 1;
        end
    end

    task send_bytes(input integer n, input integer first);
        integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            @(negedge pix_clk);
            pix_data  = (first + i) & 8'hFF;
            pix_valid = 1'b1;
        end
        @(negedge pix_clk);
        pix_valid = 1'b0;
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

    integer k;

    initial begin
        pix_rst        = 1'b1;
        m_axis_aresetn = 1'b0;
        #200;
        pix_rst        = 1'b0;
        m_axis_aresetn = 1'b1;
        #200;

        $display("--- test 1: data before start must be ignored ---");
        send_bytes(16, 0);
        #500;
        if (rx_cnt != 0) begin
            errors = errors + 1;
            $display("FAIL: %0d words accepted before start", rx_cnt);
        end else
            $display("PASS: nothing accepted before start");

        $display("--- test 2: one full frame ---");
        @(posedge m_axis_aclk) start = 1'b1;
        wait (busy);
        repeat (2) @(posedge m_axis_aclk);
        start = 1'b0;

        send_bytes(BYTES, 0);

        wait (rx_cnt == WORDS);
        repeat (20) @(posedge m_axis_aclk);

        for (k = 0; k < WORDS; k = k + 1)
            if (rx_word[k] !== expected(k)) begin
                errors = errors + 1;
                $display("FAIL: word %0d = %h, expected %h",
                         k, rx_word[k], expected(k));
            end else
                $display("PASS: word %0d = %h", k, rx_word[k]);

        if (last_at != WORDS - 1) begin
            errors = errors + 1;
            $display("FAIL: tlast at word %0d, expected %0d", last_at, WORDS - 1);
        end else
            $display("PASS: tlast on the last word");

        $display("--- test 3: extra data after the frame is ignored ---");
        send_bytes(16, 8'hA0);
        #500;
        if (rx_cnt != WORDS) begin
            errors = errors + 1;
            $display("FAIL: %0d words total, expected %0d", rx_cnt, WORDS);
        end else
            $display("PASS: frame closed after %0d words", WORDS);

        if (errors == 0) $display("=== ALL TESTS PASSED ===");
        else             $display("=== %0d ERRORS ===", errors);
        $finish;
    end

    initial begin
        #500_000;
        $display("timeout: rx_cnt = %0d of %0d, busy = %b, errors = %0d",
                 rx_cnt, WORDS, busy, errors);
        $finish;
    end

endmodule