//
// Copyright (c) 2016 University of Cambridge All rights reserved.
//
// Author: Marco Forconesi
//
// This software was developed with the support of 
// Prof. Gustavo Sutter and Prof. Sergio Lopez-Buedo and
// University of Cambridge Computer Laboratory NetFPGA team.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more
// contributor license agreements.  See the NOTICE file distributed with this
// work for additional information regarding copyright ownership.  NetFPGA
// licenses this file to you under the NetFPGA Hardware-Software License,
// Version 1.0 (the "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 100ps
//`default_nettype none

module xgmii_corrupt (

    // Clks and resets
    input                    clk,
    input                    reset,
    input                    tx_dcm_locked,
    input                    rx_dcm_locked,

    // XGMII
    input        [63:0]      xgmii_txd,
    input        [7:0]       xgmii_txc,
    output reg   [63:0]      xgmii_rxd,
    output reg   [7:0]       xgmii_rxc,

    // Sim info
    output       [63:0]      pkts_detected,
    output reg   [63:0]      corrupted_pkts
    );

    `include "localparam.dat"
    `include "corr_pkt.dat"

    localparam s0 = 8'b00000001;
    localparam s1 = 8'b00000010;
    localparam s2 = 8'b00000100;
    localparam s3 = 8'b00001000;
    localparam s4 = 8'b00010000;
    localparam s5 = 8'b00100000;
    localparam s6 = 8'b01000000;
    localparam s7 = 8'b10000000;

    //-------------------------------------------------------
    // Local
    //-------------------------------------------------------
    reg          [63:0]      fsm;
    reg          [63:0]      i, trn;

    //-------------------------------------------------------
    // assigns
    //-------------------------------------------------------
    assign pkts_detected = i;

    ////////////////////////////////////////////////
    // xgmii_corrupt
    ////////////////////////////////////////////////
    always @(posedge clk) begin

        if (reset || !tx_dcm_locked || !rx_dcm_locked) begin
            xgmii_rxd <= xgmii_txd;
            xgmii_rxc <= xgmii_txc;
            i <= 0;
            trn <= 0;
            corrupted_pkts <= 0;
            fsm <= s0;
        end

        else begin

            xgmii_rxd <= xgmii_txd;
            xgmii_rxc <= xgmii_txc;

            case (fsm)

                s0 : begin
                    if (xgmii_txc != 8'hFF) begin
                        trn <= 1;
                        fsm <= s1;
                    end
                end

                s1 : begin
                    trn <= trn + 1;
                    if (trn == 3) begin
                        if (corrupt_pkt[i]) begin
                            corrupted_pkts <= corrupted_pkts + 1;
                            xgmii_rxd <= {xgmii_txd[63:1], ~xgmii_txd[0]};
                            xgmii_rxc <= xgmii_txc;
                        end
                    end

                    if (xgmii_txc) begin
                        i <= i + 1;
                        fsm <= s0;
                    end
                end

            endcase
        end
    end

endmodule // xgmii_corrupt

//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////