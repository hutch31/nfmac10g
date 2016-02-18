/*******************************************************************************
*
*  NetFPGA-10G http://www.netfpga.org
*
*  File:
*        mac2axis.v
*
*  Project:
*
*
*  Author:
*        Marco Forconesi
*
*  Description:
*        
*
*
*    This code is initially developed for the Network-as-a-Service (NaaS) project.
*
*  Copyright notice:
*        Copyright (C) 2014 University of Cambridge
*
*  Licence:
*        This file is part of the NetFPGA 10G development base package.
*
*        This file is free code: you can redistribute it and/or modify it under
*        the terms of the GNU Lesser General Public License version 2.1 as
*        published by the Free Software Foundation.
*
*        This package is distributed in the hope that it will be useful, but
*        WITHOUT ANY WARRANTY; without even the implied warranty of
*        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
*        Lesser General Public License for more details.
*
*        You should have received a copy of the GNU Lesser General Public
*        License along with the NetFPGA source package.  If not, see
*        http://www.gnu.org/licenses/.
*
*/

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
//`default_nettype none

module mac2axis # (
    parameter AW = 9
    ) (

    // MAC Rx
    input                    s_axis_mac_aclk,
    input                    s_axis_mac_aresetn,
    input        [63:0]      s_axis_mac_tdata,
    input        [7:0]       s_axis_mac_tkeep,
    input                    s_axis_mac_tvalid,
    input                    s_axis_mac_tlast,
    input                    s_axis_mac_tuser,

    // Usr Rx
    input                    m_axis_aclk,
    input                    m_axis_aresetn,
    output       [63:0]      m_axis_tdata,
    output       [7:0]       m_axis_tkeep,
    output                   m_axis_tvalid,
    output                   m_axis_tlast,
    input                    m_axis_tready
    );

    localparam DW = 72; // tdata+tkeep

    //-------------------------------------------------------
    // Local mac2axis
    //-------------------------------------------------------
    wire                     mac_clk;
    wire                     mac_rst;
    wire                     usr_clk;
    wire                     usr_rst;

    //-------------------------------------------------------
    // Local mac2ibuf
    //-------------------------------------------------------
    wire         [AW:0]      committed_prod;
    wire         [15:0]      dropped_pkts_cnt;

    //-------------------------------------------------------
    // Local ibuf
    //-------------------------------------------------------
    wire         [AW-1:0]    wr_addr;
    wire         [DW-1:0]    wr_data;
    wire         [AW-1:0]    rd_addr;
    wire         [DW-1:0]    rd_data;

    //-------------------------------------------------------
    // Local prod_sync
    //-------------------------------------------------------
    wire         [AW:0]      committed_prod_sync;

    //-------------------------------------------------------
    // Local cons_sync
    //-------------------------------------------------------
    wire         [AW:0]      committed_cons_sync;

    //-------------------------------------------------------
    // Local dropped_pkts_cnt_sync
    //-------------------------------------------------------
    wire         [15:0]      dropped_pkts_cnt_sync;

    //-------------------------------------------------------
    // Local ibuf2axis
    //-------------------------------------------------------
    wire         [AW:0]      committed_cons;

    //-------------------------------------------------------
    // assigns
    //-------------------------------------------------------
    assign mac_clk = s_axis_mac_aclk;
    assign mac_rst = ~s_axis_mac_aresetn;
    assign usr_clk = m_axis_aclk;
    assign usr_rst = ~m_axis_aresetn;

    //-------------------------------------------------------
    // mac2ibuf
    //-------------------------------------------------------
    mac2ibuf #(
        .AW(AW),
        .DW(DW)
    ) mac2ibuf_mod (
        .clk(mac_clk),                                         // I
        .rst(mac_rst),                                         // I
        // MAC Rx
        .tdat(s_axis_mac_tdata),                               // I [63:0]
        .tkep(s_axis_mac_tkeep),                               // I [7:0]
        .tval(s_axis_mac_tvalid),                              // I
        .tlst(s_axis_mac_tlast),                               // I
        .tusr(s_axis_mac_tuser),                               // I
        // ibuf
        .wr_addr(wr_addr),                                     // O [AW-1:0]
        .wr_data(wr_data),                                     // O [DW-1:0]
        // fwd logic
        .committed_prod(committed_prod),                       // O [AW:0]
        .committed_cons(committed_cons_sync),                  // I [AW:0]
        .dropped_pkts(dropped_pkts_cnt)                        // O [15:0]
        );

    //-------------------------------------------------------
    // ibuf
    //-------------------------------------------------------
    xge_ibuf #(
        .AW(AW),
        .DW(DW)
    ) ibuf_mod (
        .a(wr_addr),                                           // I [AW-1:0]
        .d(wr_data),                                           // I [DW-1:0]
        .dpra(rd_addr),                                        // I [AW-1:0]
        .clk(mac_clk),                                         // I 
        .qdpo_clk(usr_clk),                                    // I
        .qdpo(rd_data)                                         // O [DW-1:0]
        );

    //-------------------------------------------------------
    // prod_sync
    //-------------------------------------------------------
    xge_sync_type1 #(
        .W(AW+1)
    ) prod_sync_mod (
        .clk_out(usr_clk),                                     // I
        .rst_out(usr_rst),                                     // I
        .clk_in(mac_clk),                                      // I
        .rst_in(mac_rst),                                      // I
        .in(committed_prod),                                   // I [AW:0]
        .out(committed_prod_sync)                              // O [AW:0]
        );

    //-------------------------------------------------------
    // cons_sync
    //-------------------------------------------------------
    xge_sync_type0 #(
        .W(AW+1)
    ) cons_sync_mod (
        .clk_out(mac_clk),                                     // I
        .rst_out(mac_rst),                                     // I
        .clk_in(usr_clk),                                      // I
        .rst_in(usr_rst),                                      // I
        .in(committed_cons),                                   // I [AW:0]
        .out(committed_cons_sync)                              // O [AW:0]
        );

    //-------------------------------------------------------
    // dropped_pkts_cnt_sync
    //-------------------------------------------------------
    xge_sync_type1 #(
        .W(16)
    ) dropped_pkts_cnt_sync_mod (
        .clk_out(usr_clk),                                     // I
        .rst_out(usr_rst),                                     // I
        .clk_in(mac_clk),                                      // I
        .rst_in(mac_rst),                                      // I
        .in(dropped_pkts_cnt),                                 // I [15:0]
        .out(dropped_pkts_cnt_sync)                            // O [15:0]
        );

    //-------------------------------------------------------
    // ibuf2axis
    //-------------------------------------------------------
    ibuf2axis #(
        .AW(AW),
        .DW(DW)
    ) ibuf2axis_mod (
        .clk(usr_clk),                                         // I
        .rst(usr_rst),                                         // I
        // Usr Rx
        .tdat(m_axis_tdata),                                   // O [63:0]
        .tkep(m_axis_tkeep),                                   // O [7:0]
        .tval(m_axis_tvalid),                                  // O
        .tlst(m_axis_tlast),                                   // O
        .trdy(m_axis_tready),                                  // I
        // mac2ibuf
        .committed_prod(committed_prod_sync),                  // I [AW:0]
        .committed_cons(committed_cons),                       // O [AW:0]
        // ibuf
        .rd_addr(rd_addr),                                     // O [AW-1:0]
        .rd_data(rd_data)                                      // I [DW-1:0]
        );

endmodule // mac2axis

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////