/* 
* UART Interface
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: May 1st, 2025
*
* Description:
* This interface defines the communication structure between a UART Transmitter,
* the input text buffer, and the testbench. It includes clocking blocks and modports for 
* safe synchronization, control, and observation of the UART TX flow. The interface is used
* for serialized AES ciphertext transmission.
*/

import DesignPkg::*;

interface Uart_Interface (
  input logic clk,                // System clock
  input logic reset_n,           // Active-low reset
  input logic text_ready,        // Indicates text is ready to be sent
  input text_t cipher_text,      // Input ciphertext from AES core

  output logic uart_buffer_full,
  output logic uart_serial_out   // Final UART serial line output
);

  localparam DATA_WIDTH = 8;     // UART transmits 8 bits per frame

  // Internal buffer control signals
  logic buffer_write;            // Signal to write data into FIFO buffer
  logic buffer_full;			// Signal for buffer internal FIFO full
  text_t text_in;                // Internal version of cipher_text input

  // UART Transmitter control signals
  logic tx_drive;                // Assert to start UART transmission
  logic [DATA_WIDTH-1:0] tx_byte_in; // Byte to send via UART

  // UART Transmitter status signals
  logic tx_active;               // Transmission in progress
  logic tx_serial_out;           // UART output signal
  logic tx_done;                 // Pulse when transmission finishes

  // Assign testbench or buffer-side control wiring
  assign text_in        = cipher_text;
  assign uart_serial_out = tx_serial_out;
  assign buffer_write   = text_ready;
  assign uart_buffer_full = buffer_full;

  // Clocking block for driving UART transmitter
  clocking tx_drv_cb @(posedge clk);
    default output #1ns;
    default input #1step;
    output tx_drive, tx_byte_in;
    input tx_active;
  endclocking

  // Clocking block for monitoring UART transmitter outputs
  clocking tx_mon_cb @(posedge clk);
    default input #1step;
    input tx_active, tx_serial_out, tx_done;
  endclocking

  // Clocking block for driving buffer control inputs
  clocking buff_drv_cb @(posedge clk);
    default output #1ns;
    default input #1step;
    output text_in, buffer_write;
    input buffer_full;
  endclocking

  // Modports for testbench access
  modport Tx_Driver   (clocking tx_drv_cb, input reset_n); 
  modport Tx_Monitor  (clocking tx_mon_cb, input reset_n);
  modport Buffer_Driver (clocking buff_drv_cb, input reset_n);

  // Modport for internal buffer logic
  modport Buffer (
    input clk,
    input reset_n,
    input text_in,
    input tx_active,
    input tx_done,
    input buffer_write,

    output buffer_full,
    output tx_drive,
    output tx_byte_in
  );

  // Modport for UART transmitter module
  modport Transmitter (
    input clk,
    input reset_n,
    input tx_drive,
    input tx_byte_in,

    output tx_active,
    output tx_serial_out,
    output tx_done
  );

endinterface : Uart_Interface
