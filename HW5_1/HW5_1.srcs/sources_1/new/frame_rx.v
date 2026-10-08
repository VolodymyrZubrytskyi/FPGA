`timescale 1ns / 1ps

module frame_rx #(
    parameter integer FRAME_WORDS = 16000,
    parameter integer FIFO_AW     = 4
) (
    input  wire        pix_clk,
    input  wire        pix_rst,
    input  wire [7:0]  pix_data,
    input  wire        pix_valid,

    input  wire        m_axis_aclk,
    input  wire        m_axis_aresetn,
    input  wire        start,
    output wire        busy,

    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    localparam integer DEPTH = 1 << FIFO_AW;
    localparam integer CW    = $clog2(FRAME_WORDS + 1);

    // ---- start: system domain -> pix domain ----
    reg start_s1, start_s2, start_s3;
    always @(posedge pix_clk or posedge pix_rst)
        if (pix_rst) begin
            start_s1 <= 1'b0; start_s2 <= 1'b0; start_s3 <= 1'b0;
        end else begin
            start_s1 <= start; start_s2 <= start_s1; start_s3 <= start_s2;
        end
    wire start_rise = start_s2 & ~start_s3;

    // ---- byte -> word packer (pix domain) ----
    reg         capturing;
    reg  [1:0]  byte_idx;
    reg  [31:0] word_sr;
    reg  [CW-1:0] word_cnt;

    wire        fifo_full;
    wire        byte_accept = capturing & pix_valid & ~fifo_full;
    wire [31:0] next_word   = {pix_data, word_sr[31:8]};
    wire        word_done   = byte_accept & (byte_idx == 2'd3);
    wire        last_word   = word_done & (word_cnt == FRAME_WORDS - 1);

    always @(posedge pix_clk or posedge pix_rst) begin
        if (pix_rst) begin
            capturing <= 1'b0;
            byte_idx  <= 2'd0;
            word_cnt  <= {CW{1'b0}};
            word_sr   <= 32'd0;
        end else if (!capturing) begin
            if (start_rise) begin
                capturing <= 1'b1;
                byte_idx  <= 2'd0;
                word_cnt  <= {CW{1'b0}};
            end
        end else if (byte_accept) begin
            word_sr  <= next_word;
            byte_idx <= byte_idx + 2'd1;
            if (word_done) begin
                word_cnt <= word_cnt + 1'b1;
                if (last_word) capturing <= 1'b0;
            end
        end
    end

    // ---- async FIFO, 33 bit: {tlast, data} ----
    reg [32:0] mem [0:DEPTH-1];

    wire        fifo_we    = word_done;
    wire [32:0] fifo_wdata = {last_word, next_word};
    wire        fifo_empty;
    wire        fifo_re    = m_axis_tvalid & m_axis_tready;

    reg [FIFO_AW:0] wbin, wgray, rbin, rgray;
    reg [FIFO_AW:0] wq1_rgray, wq2_rgray;
    reg [FIFO_AW:0] rq1_wgray, rq2_wgray;

    wire [FIFO_AW:0] wbin_next  = wbin + (fifo_we & ~fifo_full);
    wire [FIFO_AW:0] wgray_next = wbin_next ^ (wbin_next >> 1);
    wire [FIFO_AW:0] rbin_next  = rbin + (fifo_re & ~fifo_empty);
    wire [FIFO_AW:0] rgray_next = rbin_next ^ (rbin_next >> 1);

    always @(posedge pix_clk) if (fifo_we & ~fifo_full) mem[wbin[FIFO_AW-1:0]] <= fifo_wdata;

    always @(posedge pix_clk or posedge pix_rst)
        if (pix_rst) begin
            wbin <= 0; wgray <= 0; wq1_rgray <= 0; wq2_rgray <= 0;
        end else begin
            wbin <= wbin_next; wgray <= wgray_next;
            wq1_rgray <= rgray; wq2_rgray <= wq1_rgray;
        end

    always @(posedge m_axis_aclk or negedge m_axis_aresetn)
        if (!m_axis_aresetn) begin
            rbin <= 0; rgray <= 0; rq1_wgray <= 0; rq2_wgray <= 0;
        end else begin
            rbin <= rbin_next; rgray <= rgray_next;
            rq1_wgray <= wgray; rq2_wgray <= rq1_wgray;
        end

    assign fifo_empty = (rgray == rq2_wgray);
    assign fifo_full  = (wgray_next == {~wq2_rgray[FIFO_AW:FIFO_AW-1],
                                         wq2_rgray[FIFO_AW-2:0]});

    wire [32:0] fifo_dout = mem[rbin[FIFO_AW-1:0]];

    // ---- AXI4-Stream master ----
    assign m_axis_tdata  = fifo_dout[31:0];
    assign m_axis_tlast  = fifo_dout[32];
    assign m_axis_tkeep  = 4'hF;
    assign m_axis_tvalid = ~fifo_empty;

    // ---- busy: pix domain -> system domain ----
    reg busy_s1, busy_s2;
    always @(posedge m_axis_aclk or negedge m_axis_aresetn)
        if (!m_axis_aresetn) begin
            busy_s1 <= 1'b0; busy_s2 <= 1'b0;
        end else begin
            busy_s1 <= capturing; busy_s2 <= busy_s1;
        end
    assign busy = busy_s2 | ~fifo_empty;

endmodule