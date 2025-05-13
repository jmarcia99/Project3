/* 
* AES MixColumns Transformation Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: March 30th, 2025
*
* Description:
* This module performs the MixColumns operation from the AES-128 algorithm.
* It implements the Galois Field (GF 2^8) multiplication required to transform
* each column of the AES state matrix using matrix multiplication over GF(2^8).
* Multiplications by 2 and 3 are done using left shift and XOR with 0x1b when needed.
* The transformation is conditionally bypassed on the final round as per AES spec.
*/

import DesignPkg::*;

module Mix_Columns (AES_Core_Interface.Mix_Columns mc_if);

  // Multiply byte by 2 in GF(2^8)
  function automatic byte_t mult_by_2 (input byte_t operand); 
    byte_t result;
    result = operand << 1;
    
    if (operand[7] == 1) begin
      result = result ^ 8'h1b; // XOR with AES reduction polynomial
    end
    
    return result;
  endfunction 

  // Multiply byte by 3 in GF(2^8): (2 * x) ^ x
  function automatic byte_t mult_by_3 (input byte_t operand);
    byte_t result;
    
    result = mult_by_2(operand);
    result = result ^ operand;
    
    return result;
  endfunction 

  // Apply MixColumns matrix multiplication to a single column (word)
  function automatic word_t get_mcol_value(input word_t column);
    word_t new_column;
    
    new_column[0] = mult_by_2(column[0]) ^ mult_by_3(column[1]) ^ column[2] ^ column[3];
    new_column[1] = column[0] ^ mult_by_2(column[1]) ^ mult_by_3(column[2]) ^ column[3];
    new_column[2] = column[0] ^ column[1] ^ mult_by_2(column[2]) ^ mult_by_3(column[3]);
    new_column[3] = mult_by_3(column[0]) ^ column[1] ^ column[2] ^ mult_by_2(column[3]);
    
    return new_column;
  endfunction

  // Apply MixColumns transformation to all four columns in the AES state
  function automatic text_t f_mix_columns(input text_t state_text);
    text_t mixed_text;
    
    mixed_text[FIRST_WORD]  = get_mcol_value(state_text[FIRST_WORD]);
    mixed_text[SECOND_WORD] = get_mcol_value(state_text[SECOND_WORD]);
    mixed_text[THIRD_WORD]  = get_mcol_value(state_text[THIRD_WORD]);
    mixed_text[LAST_WORD]   = get_mcol_value(state_text[LAST_WORD]);
    
    return mixed_text;
  endfunction 

  // Conditional MixColumns application: skipped during final AES round
  always_comb begin 
    if (mc_if.round < 10)
      mc_if.next_text <= f_mix_columns(mc_if.shifted_text);
    else
      mc_if.next_text <= mc_if.shifted_text;
  end 

endmodule : Mix_Columns
