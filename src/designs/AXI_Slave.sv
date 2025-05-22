/* 
* AXI4-Lite Slave Interface Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: May 20th, 2025
*
* Description:
* This module implements an AXI4-Lite-style slave interface for memory-mapped access.
* It handles independent read and write channels, including handshake signaling,
* address/data buffering, and one-cycle memory transfers. It supports:
*  - Independent AW/W handshake with registered values
*  - Single-beat memory read and write operations
*  - AXI4-Lite response signaling (fixed OKAY response)
* The memory interface connects to internal memory via separate read/write pulses
* and address/data buses.
*/

import DesignPkg::*;

module AXI_Slave #(
  parameter DATA_WIDTH = 32,
  parameter ADDR_WIDTH = 7
)(
  AXI_Lite_Interface.Slave axi_s
);

  localparam logic [1:0] AXI_OKAY = 2'b00;
  axi_wr_fsm_e  wr_state, wr_next;

  // Flags for independent AW/W handshakes
  logic awaddr_registered, wdata_registered;
  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic [DATA_WIDTH-1:0] wdata_q;
  logic [(DATA_WIDTH/8)-1:0] wstrb_q;

  axi_rd_fsm_e  rd_state, rd_next;
  logic [ADDR_WIDTH-1:0] araddr_q;

  always_ff @(posedge axi_s.clk or negedge axi_s.reset_n) begin : State_Registers
    if (!axi_s.reset_n) begin
      wr_state <= WR_IDLE;
      rd_state <= RD_IDLE;
    end 
    else begin
      wr_state <= wr_next;
      rd_state <= rd_next;
    end
  end

  // ===========================
  // Write Channel Logic
  // ===========================
  always_ff @(posedge axi_s.clk or negedge axi_s.reset_n) begin : Write_Channel_Handling
    if (!axi_s.reset_n) begin
      awaddr_registered <= '0;
      wdata_registered  <= '0;
      awaddr_q <= '0;
      wdata_q  <= '0;
      wstrb_q  <= '0;
    end 
    else begin  

      if (!awaddr_registered && axi_s.awvalid && axi_s.awready) begin
        awaddr_registered <= 1'b1;
        awaddr_q <= axi_s.awaddr;
      end 
      else if (wr_state == WR_RESP && wr_next == WR_IDLE) begin
        awaddr_registered <= 1'b0;
      end
  
      if (!wdata_registered && axi_s.wvalid && axi_s.wready) begin
        wdata_registered <= 1'b1;
        wdata_q <= axi_s.wdata;
        wstrb_q <= axi_s.wstrb;
      end 
      else if (wr_state == WR_RESP && axi_s.bready) begin
        wdata_registered <= 1'b0;
      end
    end
  end

  always_comb begin : Write_State_Transitions
    wr_next = WR_XX;
    case (wr_state)
      WR_IDLE : begin
        		  if (awaddr_registered && wdata_registered) 	wr_next = WR_DATA;
                  else 											wr_next = WR_IDLE;
                end
      
      WR_DATA : 												wr_next = WR_RESP; // one‑cycle memory write

      WR_RESP : begin
                  if (axi_s.bready) 							wr_next = WR_IDLE;
                  else 											wr_next = WR_RESP;
                end
      
      default : wr_next = WR_XX;
    endcase
  end

  always_comb begin : Write_State_Combinatorial_Outputs
    // Handshake lines
    axi_s.awready = (wr_state == WR_IDLE && !awaddr_registered);
    axi_s.wready  = (wr_state == WR_IDLE && !wdata_registered);

    // Memory write pulse (single beat)
    axi_s.mem_write   = (wr_state == WR_DATA);
    axi_s.mem_wr_addr = awaddr_q;
    axi_s.mem_data_in = wdata_q;
    axi_s.mem_wstrb   = wstrb_q;
 
    // Response channel (always OKAY)
    axi_s.bvalid = (wr_state == WR_RESP);
    axi_s.bresp  = AXI_OKAY;
  end
  
  // ===========================
  // Read Channel Logic
  // ===========================
  always_ff @(posedge axi_s.clk or negedge axi_s.reset_n) begin : Read_Channel_Handling
    if (!axi_s.reset_n) begin
      araddr_q <= '0;
    end 
    else if (axi_s.arvalid && axi_s.arready) begin
      araddr_q <= axi_s.araddr;
    end
  end
  
  always_comb begin : Read_State_Transitions
    rd_next = RD_XX;
    case (rd_state)
      RD_IDLE : begin
                  if (axi_s.arvalid)		rd_next = RD_DATA;
                  else					 	rd_next = RD_IDLE;
                end
      
      RD_DATA : 							rd_next = RD_RESP; // one‑cycle memory read
                
      RD_RESP : begin
                  if (axi_s.rready)		 	rd_next = RD_IDLE;
                  else						rd_next = RD_RESP;
                end
      
      default : rd_next = RD_XX;
    endcase
  end

  always_comb begin : Read_State_Combinatorial_Outputs
    // Address handshake
    axi_s.arready     = (rd_state == RD_IDLE);

    // Memory read pulse
    axi_s.mem_read    = (rd_state == RD_DATA);
    axi_s.mem_rd_addr = araddr_q;

    // Data / response back to master
    axi_s.rvalid      = (rd_state == RD_RESP);
    axi_s.rdata       = axi_s.mem_data_out;
    axi_s.rresp       = AXI_OKAY;
  end

endmodule : AXI_Slave
