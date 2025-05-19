/* 
* Uart Transmitter Assertions
* Created By: Jordi Marcial Cruz
* Updated: April 2nd, 2025
*
* Description:
* This module defines SystemVerilog assertions to verify the functional correctness
* of a UART transmitter module used in the AES-128 system. Assertions monitor FSM
* transitions, timing behavior, signal consistency, and correct data sequencing 
* during UART transmission.
*/

import DesignPkg::*;

module Uart_Tx_Asserts #(
  localparam DATA_WIDTH = 8
)(
  input logic clk,
  input logic reset_n,
  input logic tx_drive,
  input logic [DATA_WIDTH-1:0] tx_byte_in,

  input logic tx_active,
  input logic tx_serial_out,
  input logic tx_done,

  input uart_tx_fsm_e state,
  input uart_tx_fsm_e next_state,
  input logic [31:0] clk_count,
  input logic [3:0] bit_index
);

  // Macro for assertions on rising edge of clk with reset disable condition
  `define assert_clk(arguments) \
  assert property (@(posedge clk) disable iff (!reset_n) arguments)

  ERROR_DATA_LINE_NOT_HELD_HIGH: 
    `assert_clk((state == IDLE) || (state == TX_STOP) |-> ##1 tx_serial_out);
  
  ERROR_TRANSMITTER_IS_NOT_ACTIVE: 
    `assert_clk((state == IDLE) && tx_drive |-> ##1 $rose(tx_active) ##434 $stable(tx_active));
  
  ERROR_DATA_TRANSFER_FAILED_TO_START: 
    `assert_clk((state == TX_START) && (clk_count == 433) |-> ##1 (state == TX_DATA) ##434 (bit_index == 1));
  
  ERR0R_CLK_COUNT_OR_BIT_INDEX_OUT_OF_RANGE: 
    `assert_clk((state == TX_DATA) && (clk_count == 433) |-> ##1 (clk_count == 0) && (bit_index < 9));

  ERROR_BIT_INDEX_FAILED_TO_RESET:
    `assert_clk((bit_index == 8) |-> ##1 (state == TX_STOP) ##1 (bit_index == 0));

  ERROR_NOT_ALL_DATA_SENT:
    `assert_clk((next_state == TX_STOP) && (clk_count == 433) |-> bit_index == 7 ##1 bit_index == 0);

  ERROR_DATA_TRANSFER_NOT_DONE:
    `assert_clk((state == TX_STOP) && (clk_count == 433) |-> ##1 $rose(tx_done) ##1 $fell(tx_done));

endmodule : Uart_Tx_Asserts
