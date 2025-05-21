/*
* Output Buffer Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 28th, 2025
*
* Description:
* This module manages the buffering and sequencing of AES-128 ciphertext blocks
* to be transmitted over UART. It instantiates a FIFO to store 128-bit encrypted
* blocks, then serializes each block byte-by-byte based on UART transmitter readiness.
* A FSM controls the reading, waiting, and byte-wise transmission states.
*/

import DesignPkg::*;

module Output_Buffer #(
  parameter DATA_WIDTH = 128,
  localparam ADDR_WIDTH = $clog2(DATA_WIDTH)
)(
  Uart_Interface.Buffer buff_if
);
  
  logic					fifo_empty;
  logic					fifo_full;
  logic					fifo_read;
  logic					text_registered;
  logic					text_sent;
  logic [0:15][7:0] 	text_out;
  
  logic 				byte_ready;
  logic [3:0] 			byte_index; 
  logic [0:15][7:0] 	cipher_text;
  
  buffer_fsm_e state, next_state;
  
  Fifo_Buffer #(
    .DATA_WIDTH		(DATA_WIDTH),
    .ADDR_WIDTH		(ADDR_WIDTH)
  ) Cipher_Text_Fifo (
    .clock			(buff_if.clk),
    .reset_n		(buff_if.reset_n),
    .rden			(fifo_read),
    .wren			(buff_if.buffer_write),
    .empty			(fifo_empty),
    .full			(fifo_full),
    .data_in		(buff_if.text_in),
    .data_out		(text_out)
  );
  
  always_ff @(posedge buff_if.clk or negedge buff_if.reset_n) begin : State_Register
    if (!buff_if.reset_n) 	state <= BUFF_READ;
    else  					state <= next_state;
  end  
  
  always_comb begin 
    next_state = BUFF_XX;
    case (state) 
      BUFF_READ :   if (text_registered) 								next_state = BUFF_WAIT;
      				else												next_state = BUFF_READ;
        
      BUFF_WAIT : 	if (!buff_if.tx_active)								next_state = BUFF_SEND;
        			else												next_state = BUFF_WAIT;
        
      BUFF_SEND : 	if (byte_index == 15)								next_state = BUFF_READ;
      				else												next_state = BUFF_WAIT;
      
      default	:														next_state = BUFF_XX;
    endcase
  end               
  
  always_ff @(posedge buff_if.clk or negedge buff_if.reset_n) begin : State_Registered_Outputs
    if (!buff_if.reset_n) begin 
      byte_index <= '0;
      cipher_text <= '0;
	  text_registered <= '0;
    end
    else begin 
	  text_registered <= '0;
      byte_index <= byte_index;
      cipher_text <= cipher_text;
      case (state) 
        BUFF_READ : 	begin
                          if (!fifo_empty) begin 
                            cipher_text <= '0;
                            text_registered <= '1; 
                          end
          
                          if (text_registered) 	begin 
                            cipher_text <= text_out;
                            text_registered <= '0;
                          end
        				end
          
        BUFF_WAIT : 	; 
                      
        BUFF_SEND : 	begin
          				  if (byte_index < 15) 	byte_index <= byte_index + 4'b1;
                          else					byte_index <= '0;
        				end			
        
        default	:		begin
                          text_registered <= 'x;
                          byte_index <= 'x;
                          cipher_text <= 'x;
                        end
      endcase
    end   
  end 
  
  always_comb begin : State_Combinatorial_Outputs
    byte_ready = '0;
    fifo_read = '0;	
    case (state) 
            BUFF_READ : 	begin 
              				  if (!fifo_empty && !text_registered)  fifo_read = '1;
              			      else									fifo_read = '0;
            				end

            BUFF_WAIT : 	; 

            BUFF_SEND : 	begin
                              byte_ready = '1;
                            end			

            default	:		begin
                              byte_ready = 'x;
              				  fifo_read = 'x;
                            end
    endcase
  end 
  
  assign buff_if.tx_byte_in = cipher_text[byte_index];
  assign buff_if.tx_drive = byte_ready;
  assign buff_if.buffer_full = fifo_full;
                            
endmodule : Output_Buffer 
