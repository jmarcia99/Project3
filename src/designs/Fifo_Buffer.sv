/*
* FIFO Buffer Module
* Created By: Jordi Marcial Cruz
* Updated: Febraury 30th, 2025
*
* Description:
* This module implements a synchronous FIFO buffer with separate read and write pointers,
* wrap-around logic, and full/empty flag generation. It supports simultaneous read/write
* operations and ensures safe handling of corner cases such as full/empty transitions.
* The module is parameterizable for data width and depth.
*/

module Fifo_Buffer #(
  parameter DATA_WIDTH = 7,
  			ADDR_WIDTH = 2 
)(
  input logic 						clock,
  input logic 						reset_n,
  input logic 						rden,
  input logic 						wren,
  input logic [DATA_WIDTH-1:0]		data_in,
  
  output logic 						empty,
  output logic 						full,
  output logic [DATA_WIDTH-1:0] 	data_out
);
  
  localparam MEM_DEPTH = 2**ADDR_WIDTH;
  
  logic [DATA_WIDTH-1:0] memory [MEM_DEPTH];
  logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
  logic [ADDR_WIDTH:0] counter;
  
  assign full = (counter == MEM_DEPTH) ? '1 : '0;
  assign empty = (counter == 0) ? '1 : '0;
  
  always_ff @(posedge clock or negedge reset_n) begin 
    if (!reset_n) begin 
      memory <= '{default: '0};
      wr_ptr <= '0;
      rd_ptr <= '0;
      counter <= '0;
      data_out <= '0;
    end 
    else begin 
      if (rden && wren && !empty && !full) begin
        data_out <= memory[rd_ptr];
        memory[wr_ptr] <= data_in;
        counter <= counter;
        
        if (rd_ptr == MEM_DEPTH - 1) 	rd_ptr <= 0;
        else							rd_ptr <= rd_ptr + 1;
        
        if (wr_ptr == MEM_DEPTH - 1) 	wr_ptr <= 0;
          else							wr_ptr <= wr_ptr + 1;
      end 
      else begin 
        if (rden && !empty) begin 
          data_out <= memory[rd_ptr];
          counter <= counter - 1;

          if (rd_ptr == MEM_DEPTH - 1) 	rd_ptr <= 0;
          else							rd_ptr <= rd_ptr + 1;
        end 

        if (wren && !full) begin 
          memory[wr_ptr] <= data_in;
          counter <= counter + 1;

          if (wr_ptr == MEM_DEPTH - 1) 	wr_ptr <= 0;
          else							wr_ptr <= wr_ptr + 1;
        end 
      end
    end 
  end 
  
endmodule : Fifo_Buffer
  
  
