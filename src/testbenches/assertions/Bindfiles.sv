/*
* Assertion Bindfile Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: May 2nd, 2025
*
* Description:
* This module binds assertion modules to their respective design modules using the SystemVerilog bind construct.
* These assertions are used to functionally verify the internal behavior of:
*   - UART Transmitter (`Uart_Tx`) via `Uart_Tx_Asserts`
*   - Output Buffer (`Output_Buffer`) via `Output_Buffer_Asserts`
* 
* The connected signals are passed into assertion modules from the top-level design hierarchy, allowing
* for verification without modifying the design source code.
*/

// Need to add other asserts into this file
module Bindfiles;

  bind Uart_Tx Uart_Tx_Asserts Uart_Tx_Assertions (
    .clk						(tx_if.clk),
    .reset_n					(tx_if.reset_n),
    .tx_drive					(tx_if.tx_drive),
    .tx_byte_in					(tx_if.tx_byte_in),
    .tx_active					(tx_if.tx_active),
    .tx_serial_out				(tx_if.tx_serial_out),
    .tx_done					(tx_if.tx_done),
    .state						(state),
    .next_state					(next_state),
    .clk_count					(clk_count),
    .bit_index					(bit_index)
  );
  
  bind Output_Buffer Output_Buffer_Asserts Output_Buffer_Assertions (
    .clk						(buff_if.clk),
    .reset_n					(buff_if.reset_n), 
    .text_in					(buff_if.text_in),
    .tx_active					(buff_if.tx_active),
    .tx_done					(buff_if.tx_done),
    .buffer_write				(buff_if.buffer_write),
    .tx_drive					(buff_if.tx_drive),
    .tx_byte_in					(buff_if.tx_byte_in),
    .state						(state),
    .next_state					(next_state),
    .fifo_empty					(fifo_empty),
    .fifo_full					(fifo_full),
    .fifo_read					(fifo_read),
    .text_registered			(text_registered),
    .text_sent					(text_sent),
    .byte_ready					(byte_ready),
    .byte_index					(byte_index), 
    .text_out					(text_out),
    .cipher_text				(cipher_text)
  );
  
endmodule : Bindfiles
