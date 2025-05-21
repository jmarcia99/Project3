/* 
* Output Buffer Assertions
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 17th 2025
*
* Description:
* This module defines SystemVerilog assertions to verify the correct
* operation of the Output Buffer module in the AES-128 UART transmission pipeline.
* These assertions focus on validating the control sequence during FIFO reads,
* UART byte handoff, and ciphertext transmission.
*/

import DesignPkg::*;

module Output_Buffer_Asserts #(
  localparam DATA_WIDTH = 8
)(
  input logic clk,
  input logic reset_n,
  input text_t text_in,
  input logic tx_active,
  input logic tx_done,
  input buffer_write,
  
  input logic tx_drive,
  input logic [DATA_WIDTH-1:0] tx_byte_in,
  
  input buffer_fsm_e state,
  input buffer_fsm_e next_state,
 
  input logic fifo_empty,
  input logic fifo_full,
  input logic fifo_read,
  input logic text_registered,
  input logic text_sent,
  input logic byte_ready,
  input logic [3:0] byte_index,
  input logic [0:15][7:0] text_out,
  input logic [0:15][7:0] cipher_text
);

  // Macro for assertions on rising edge of clk with reset disable condition
  `define assert_clk(arguments) \
  assert property (@(posedge clk) disable iff (!reset_n) arguments)
    
  sequence read_state_sqc;
    $rose(fifo_read) ##1 $rose(text_registered) && $fell(fifo_read) ##1 $fell(text_registered) && (state == BUFF_WAIT);
  endsequence
    
  ERROR_INCORRECT_READ_STATE_SEQUENCE:
    `assert_clk((state == BUFF_READ) && !fifo_empty && !text_registered |-> read_state_sqc);
    
  ERROR_UART_NOT_DRIVEN: 
    `assert_clk((state == BUFF_WAIT) && !tx_active |-> ##1 $rose(tx_drive) ##1 $fell(tx_drive));
    
  ERROR_INCOMPLETE_CIPHER_TEXT_SENT:
    `assert_clk((state == BUFF_SEND)  && (byte_index < 15) && tx_active |-> ##1 (state == BUFF_WAIT));
    
  ERROR_CIPHER_TEXT_SENT_AGAIN:
    `assert_clk((state == BUFF_SEND) && (byte_index == 15) && tx_active |-> ##1 (state == BUFF_READ));
    
    
endmodule : Output_Buffer_Asserts
