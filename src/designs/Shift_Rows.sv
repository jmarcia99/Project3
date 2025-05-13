/* 
* AES ShiftRows Transformation Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: March 15th, 2025
*
* Description:
* This module implements the AES-128 ShiftRows transformation.
* It cyclically shifts the rows of the AES state matrix to the left by their row index.
*/

import DesignPkg::*;

module Shift_Rows (AES_Core_Interface.Shift_Rows sr_if);

  function automatic text_t f_shift_rows (
    input text_t state
  );
    text_t shifted;

    // Row 0 (no shift)
    shifted[FIRST_WORD][0]  = state[FIRST_WORD][0];
    shifted[SECOND_WORD][0] = state[SECOND_WORD][0];
    shifted[THIRD_WORD][0]  = state[THIRD_WORD][0];
    shifted[LAST_WORD][0]   = state[LAST_WORD][0];

    // Row 1 (shift left by 1)
    shifted[FIRST_WORD][1]  = state[SECOND_WORD][1];
    shifted[SECOND_WORD][1] = state[THIRD_WORD][1];
    shifted[THIRD_WORD][1]  = state[LAST_WORD][1];
    shifted[LAST_WORD][1]   = state[FIRST_WORD][1];

    // Row 2 (shift left by 2)
    shifted[FIRST_WORD][2]  = state[THIRD_WORD][2];
    shifted[SECOND_WORD][2] = state[LAST_WORD][2];
    shifted[THIRD_WORD][2]  = state[FIRST_WORD][2];
    shifted[LAST_WORD][2]   = state[SECOND_WORD][2];

    // Row 3 (shift left by 3)
    shifted[FIRST_WORD][3]  = state[LAST_WORD][3];
    shifted[SECOND_WORD][3] = state[FIRST_WORD][3];
    shifted[THIRD_WORD][3]  = state[SECOND_WORD][3];
    shifted[LAST_WORD][3]   = state[THIRD_WORD][3];

    return shifted;
  endfunction

  // Combinational assignment of ShiftRows result to output
  assign sr_if.shifted_text = f_shift_rows(sr_if.sbox_value);

endmodule : Shift_Rows
