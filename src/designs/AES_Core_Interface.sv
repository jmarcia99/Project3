/*
* AES Core Interface
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 29th, 2025
*
* Description:
* This interface defines the signal connections and communication structure 
* between AES encryption components (controller, datapath modules, and key expansion) and 
* the testbench environment. It includes:
*   - Shared data/control signals for encryption flow
*   - Clocking blocks to safely sample and drive signals in testbenches
*   - Modports for separating concerns (driver vs monitor, testbench vs RTL)
*/

import DesignPkg::*;

interface AES_Core_Interface ( 
  input  logic clk,                // System clock
  input  logic reset_n,           // Active-low synchronous reset
  input  logic start_encrypt,     // Trigger to start encryption
  input  logic output_buffer_full, // Input full signal from buffer
  input  text_t provided_text,    // Input plaintext
  input  key_t provided_key,      // Input AES key

  output text_t final_text,     // Final encrypted output
  output logic finished_encrypt   // High when encryption is complete
);

  // Internal shared signals between modules
  logic start_encryption;         // Internal control trigger
  text_t plain_text;              // Latched plaintext
  key_t original_key;             // Latched encryption key

  text_t encrypted_text;          // Output from AES controller
  logic finished_encryption;      // Completion signal

  // Interface signal assignments (input/output bridging)
  assign start_encryption = start_encrypt && output_buffer_full;
  assign plain_text       = provided_text;
  assign original_key     = provided_key;
  assign final_text       = encrypted_text;
  assign finished_encrypt = finished_encryption;

  // Internal AES datapath and control signals
  logic       start_expansion;
  logic [3:0] round;
  key_t       prev_key;
  logic       finished_expansion;
  key_t       next_key;
  text_t      shifted_text;
  text_t      next_text;
  sbox_t      sbox_addr;
  sbox_t      sbox_value;

  // Clocking block for Key Expansion driver
  clocking kx_drv_cb @(posedge clk);
    default output #1ns;
    output start_expansion, round, prev_key;
  endclocking

  // Clocking block for Key Expansion monitor
  clocking kx_mon_cb @(posedge clk);
    default input #1step;
    input finished_expansion, next_key;
  endclocking

  // Clocking block for AES controller driver
  clocking aes_drv_cb @(posedge clk);
    default output #1ns;
    default input #1step;
    output start_encryption, plain_text, original_key;
    input output_buffer_full;
  endclocking

  // Clocking block for AES controller monitor
  clocking aes_mon_cb @(posedge clk);
    default input #1step;
    input encrypted_text, finished_encryption;
  endclocking

  // Testbench-facing modports
  modport Key_Exp_Driver   (clocking kx_drv_cb, input reset_n);
  modport Key_Exp_Monitor  (clocking kx_mon_cb, input reset_n);
  modport AES_Driver       (clocking aes_drv_cb, input reset_n);
  modport AES_Monitor      (clocking aes_mon_cb, input reset_n);

  // Design-facing modports for structural connections
  modport AES_Controller (
    input  clk,
    input  reset_n,
    input  original_key,
    input  plain_text,
    input  next_text,
    input  next_key,
    input  start_encryption,
    input  finished_expansion,

    output round,
    output prev_key,
    output sbox_addr,
    output start_expansion,
    output encrypted_text,
    output finished_encryption
  );

  modport Key_Exp (
    input  clk,
    input  reset_n,
    input  start_expansion,
    input  prev_key,

    output finished_expansion,
    output next_key
  );

  modport SBox (
    input  clk,
    input  sbox_addr,
    output sbox_value
  );

  modport Shift_Rows (
    input  sbox_value,
    output shifted_text
  );

  modport Mix_Columns (
    input  clk,
    input  reset_n,
    input  round,
    input  shifted_text,
    output next_text
  );

endinterface : AES_Core_Interface
