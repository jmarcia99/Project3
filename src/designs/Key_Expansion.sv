/* 
* AES-128 Key Expansion Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 1st, 2025
*
* Description:
* This module implements the AES-128 key expansion logic.
* The key expansion generates the next 128-bit round key from the previous key.
* It uses a substitution-permutation approach involving an S-box and Rcon table,
* implements logic to rotate and substitute the last word of the previous key,
* and incrementally XORs the result to form the next key. 
*/

import DesignPkg::*;

module Key_Expansion (AES_Core_Interface.Key_Exp kx_if);

  logic [3:0] round;
  word_t rcon_word;
  word_t sub_word;
  key_t  prev_key_q;
  key_t  prev_key_d;
  key_t  next_key_calc;
  sbox_t sbox_in_bytes;
  sbox_t sbox_out_bytes;

  kx_fsm_e state, next_state;

  // Function to generate intermediate XORed key
  function automatic key_t xor_key (
    input key_t prev_key
  );
    key_t xor_of_prev_key;
    xor_of_prev_key[FIRST_WORD] = prev_key[FIRST_WORD];
    xor_of_prev_key[SECOND_WORD] = xor_of_prev_key[FIRST_WORD] ^ prev_key[SECOND_WORD];
    xor_of_prev_key[THIRD_WORD] = xor_of_prev_key[SECOND_WORD] ^ prev_key[THIRD_WORD];
    xor_of_prev_key[LAST_WORD] = xor_of_prev_key[THIRD_WORD] ^ prev_key[LAST_WORD]; 
    
    return xor_of_prev_key;
  endfunction 

  // Function to expand a key using XORed key, sub_word and Rcon
  function automatic key_t expand_key (
    input key_t xor_of_prev_key,
    input word_t sub_word,
    input word_t rcon_word
  );
    key_t new_key;
    new_key[FIRST_WORD]  = xor_of_prev_key[FIRST_WORD]  ^ sub_word ^ rcon_word;
    new_key[SECOND_WORD] = xor_of_prev_key[SECOND_WORD] ^ sub_word ^ rcon_word;
    new_key[THIRD_WORD]  = xor_of_prev_key[THIRD_WORD]  ^ sub_word ^ rcon_word;
    new_key[LAST_WORD]   = xor_of_prev_key[LAST_WORD]   ^ sub_word ^ rcon_word;
    return new_key;
  endfunction

  // FSM State Register
  always_ff @(posedge kx_if.clk or negedge kx_if.reset_n) begin : State_Register
    if (!kx_if.reset_n) state <= RECV_KEY;
    else                state <= next_state;
  end

  // FSM Next State Logic
  always_comb begin : State_Transitions 
    next_state = XX;
    case (state) 
      RECV_KEY : if (kx_if.start_expansion) 	next_state = SEND_KEY;
                 else                       	next_state = RECV_KEY;
      
      SEND_KEY : if (round == 10)           	next_state = RECV_KEY;
                 else                       	next_state = SEND_KEY;
      
      default  :                            	next_state = XX;
    endcase
  end 

  // FSM Output and State-dependent Data Updates
  always_ff @(posedge kx_if.clk or negedge kx_if.reset_n) begin : State_Registered_Outputs
    if (!kx_if.reset_n) begin
      round      <= '0;
      prev_key_q <= '0;
    end else begin
      prev_key_q <= prev_key_d;
      case (state)
        RECV_KEY : 	if (kx_if.start_expansion) 	round <= 1;
          			else                        round <= 0;
        
        SEND_KEY : 	if (round == 10) 			round <= 0;
          			else              			round <= round + 1;
        
        default  :  begin
          				round <= 'x;
          				prev_key_q <= 'x;
        			end
      endcase
    end
  end

  // Combinational Output Logic for FSM
  always_comb begin : State_Combinatorial_Outputs
    sbox_in_bytes            = '0;
    next_key_calc            = '0;
    prev_key_d               = prev_key_q;
    kx_if.next_key           = '0;
    kx_if.finished_expansion = '0;

    case (state)
      RECV_KEY : begin
                    // Rotate last word and prepare S-box inputs
                    sbox_in_bytes[BYTE0] = kx_if.prev_key[LAST_WORD][BYTE1];
                    sbox_in_bytes[BYTE1] = kx_if.prev_key[LAST_WORD][BYTE2];
                    sbox_in_bytes[BYTE2] = kx_if.prev_key[LAST_WORD][BYTE3];
                    sbox_in_bytes[BYTE3] = kx_if.prev_key[LAST_WORD][BYTE0];

                    prev_key_d = xor_key(kx_if.prev_key);
                  end

      SEND_KEY : begin
                  	// Form substituted word from S-box output
                  	sub_word = {sbox_out_bytes[BYTE0],
                              	sbox_out_bytes[BYTE1],
                              	sbox_out_bytes[BYTE2],
                              	sbox_out_bytes[BYTE3]};

                    // Expand the key
                    next_key_calc = expand_key(prev_key_q, sub_word, rcon_word);

                    // Preload for next round (feedback loop)
                    sbox_in_bytes[BYTE0] = next_key_calc[LAST_WORD][BYTE1];
                    sbox_in_bytes[BYTE1] = next_key_calc[LAST_WORD][BYTE2];
                    sbox_in_bytes[BYTE2] = next_key_calc[LAST_WORD][BYTE3];
                    sbox_in_bytes[BYTE3] = next_key_calc[LAST_WORD][BYTE0];

                    kx_if.next_key       = next_key_calc;
                    prev_key_d           = xor_key(next_key_calc);

                    if (round == 10) kx_if.finished_expansion = '1;
                  end
      
        default :  begin
                      sbox_in_bytes            = 'x;
                      next_key_calc            = 'x;
                      prev_key_d               = 'x;
                      kx_if.next_key           = 'x;
                      kx_if.finished_expansion = 'x;
        			end
    endcase
  end

  // RCON Table ROM Instantiation 
  SINGLE_PORT_ROM #(
    .ADDR_WIDTH (4),
    .DATA_WIDTH (32),
    .INIT       ("aes_rcon.mif")
  ) rcon_table (
    .clock   (kx_if.clk),
    .rden    (1'b1),
    .address (round + 4'b1),
    .q       (rcon_word)
  );

  // SBOX ROM Instantiations
  genvar a;
  generate 
    for(a = 0; a < 2; a++) begin : sbox_tables 
      DUAL_PORT_ROM #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (8),
        .INIT       ("aes_sbox.mif")
      ) sbox_table (
        .clock     (kx_if.clk),
        .rden_a    (1'b1),
        .address_a (sbox_in_bytes[a]),
        .q_a       (sbox_out_bytes[a]),
        .rden_b    (1'b1),
        .address_b (sbox_in_bytes[a+2]),
        .q_b       (sbox_out_bytes[a+2])
      );
    end
  endgenerate

endmodule : Key_Expansion
