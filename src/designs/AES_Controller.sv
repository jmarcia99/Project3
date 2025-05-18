/* 
* AES Encryption Controller Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 16th, 2025
*
* Description:
* This module coordinates the overall AES-128 encryption process using a finite state machine.
* It manages the transition between plaintext reception and round-based encryption control.
* The controller handles:
*   - Round tracking
*   - Initiating key expansion
*   - Driving XOR-based transformations before SubBytes and after MixColumns
*   - Outputting the final ciphertext and signaling completion
*/

module AES_Controller (AES_Core_Interface.AES_Controller cntrl_if);

  cntrl_fsm_e state, next_state;
  logic [3:0] round;
  
  always_ff @(posedge cntrl_if.clk or negedge cntrl_if.reset_n) begin : State_Register
    if (!cntrl_if.reset_n) 	state <= RECV_TEXT;
    else					state <= next_state;
  end
  
  always_comb begin : State_Transitions
    next_state = XXX;
    case(state)
      RECV_TEXT			:	if (cntrl_if.start_encryption)					next_state = ENCRYPT_TEXT;
      						else											next_state = RECV_TEXT;
        
      ENCRYPT_TEXT		:	if (cntrl_if.finished_expansion)				next_state = RECV_TEXT;
      						else 											next_state = ENCRYPT_TEXT;
        
      default			:													next_state = XXX;
      
    endcase
  end 
  
  always_ff @(posedge cntrl_if.clk or negedge cntrl_if.reset_n) begin : State_Registered_Outputs
    if (!cntrl_if.reset_n) begin 
      cntrl_if.encrypted_text <= '0;
      cntrl_if.finished_encryption <= '0;
      round <= '0;
    end else begin 
      cntrl_if.encrypted_text <= '0;
      cntrl_if.finished_encryption <= '0;
      round <= round;
      case(state)
        RECV_TEXT		:	if (cntrl_if.start_encryption) 	round <= round + 1;
        					else							round <= '0;

        ENCRYPT_TEXT	:	begin 
          						round <= round + 1;
          						
          					if (cntrl_if.finished_expansion) begin 
                                  cntrl_if.finished_encryption <= '1;
                                  cntrl_if.encrypted_text <= cntrl_if.sbox_addr;
                                  round <= '0;
                                end
        					end
        
        default			:	begin 
          						cntrl_if.encrypted_text <= 'x;
                                cntrl_if.finished_encryption <= 'x;
                                round <= 'x;
        					end
      endcase
    end
  end   
  
  always_comb begin : State_Combinatorial_Outputs
    cntrl_if.start_expansion = '0;
    cntrl_if.prev_key = '0;
    cntrl_if.sbox_addr = '0;
    cntrl_if.round = '0;
    case(state)
      RECV_TEXT			:	begin
        						cntrl_if.sbox_addr = cntrl_if.plain_text ^ cntrl_if.original_key;
        						cntrl_if.prev_key = cntrl_if.original_key;
        
        						if (cntrl_if.start_encryption) begin 
                                  	cntrl_if.start_expansion = 1;
                                end
      						end
        
      ENCRYPT_TEXT		:	begin 
    							cntrl_if.round = round;
        						cntrl_if.sbox_addr = cntrl_if.next_text ^ cntrl_if.next_key;
      						end
        
      default 			:	begin 
        						cntrl_if.start_expansion = 'x;
    							cntrl_if.prev_key = 'x;
    							cntrl_if.round = 'x;
      						end
    endcase
    
  end 

          
endmodule : AES_Controller
