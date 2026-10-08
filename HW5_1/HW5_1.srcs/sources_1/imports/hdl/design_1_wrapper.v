//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2026.1 (win64) Build 6511674 Tue Jun 16 11:02:23 MDT 2026
//Date        : Thu Oct  8 12:41:12 2026
//Host        : WIN-TEOC50460BP running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (pix_clk_0,
    pix_data_0,
    pix_rst_0,
    pix_valid_0,
    push_buttons_4bits_tri_i,
    reset,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  input pix_clk_0;
  input [7:0]pix_data_0;
  input pix_rst_0;
  input pix_valid_0;
  input [3:0]push_buttons_4bits_tri_i;
  input reset;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire pix_clk_0;
  wire [7:0]pix_data_0;
  wire pix_rst_0;
  wire pix_valid_0;
  wire [3:0]push_buttons_4bits_tri_i;
  wire reset;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  design_1 design_1_i
       (.pix_clk_0(pix_clk_0),
        .pix_data_0(pix_data_0),
        .pix_rst_0(pix_rst_0),
        .pix_valid_0(pix_valid_0),
        .push_buttons_4bits_tri_i(push_buttons_4bits_tri_i),
        .reset(reset),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule
