/* 
* UART Transmitter Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: March 12th, 2025
*
* Description:
* This module implements a UART transmitter that sends an 8-bit byte serially over a single line.
* It uses a finite state machine to control the start bit, data bits, and stop bit timing.
* The transmission timing is driven by the CLKS_PER_BIT parameter, which determines the baud rate.
* The transmitter begins operation upon detecting a valid transmission request (tx_drive) and indicates
* transmission status via tx_active and tx_done signals.
*/
  
module Uart_Tx #(
  parameter CLKS_PER_BIT = 434,
  parameter DATA_WIDTH = 8
)(
  Uart_Interface.Transmitter tx_if
);
  
  typedef enum logic [1:0] {
   							IDLE        = 2'b00,
  							TX_START 	= 2'b01,
                        	TX_DATA 	= 2'b10,
  							TX_STOP  	= 2'b11, 
    						XX			= 'x			} state_e;
  
  state_e state;
  state_e next_state; 
  
  logic [DATA_WIDTH-1:0] clk_count;
  logic [DATA_WIDTH-1:0] tx_data;
  
  logic [3:0] bit_index;
  
  always_ff @(posedge tx_if.clk or negedge tx_if.reset_n) begin : State_Register
    if (!tx_if.reset_n) 	state <= IDLE;
    else			state <= next_state;
  end
  
  always_comb begin : State_Transitions
    next_state = XX;
    
    case(state)
      IDLE : 			if (i_Tx_DV == 1)					next_state = TX_START;
      					else								next_state = IDLE;
        
      TX_START	 : 		if (clk_count < CLKS_PER_BIT-1) 	next_state = TX_START;
      					else								next_state = TX_DATA;
        
      TX_DATA :			if (bit_index < 8)  				next_state = TX_DATA;
      					else								next_state = TX_STOP;
        
      TX_STOP :			if (clk_count < CLKS_PER_BIT-1) 	next_state = TX_STOP;
        				else								next_state = IDLE;
      
      default:												next_state = XX;
      
    endcase
  end 
     
  always_ff @(posedge tx_if.clk or negedge tx_if.reset_n) begin : State_Registered_Outputs 
    if (!tx_if.reset_n) begin 
      tx_if.tx_serial_out <= '0;
      clk_count <= '0;
      tx_data <= '0;
      bit_index <= '0;
      tx_if.tx_done <= '0;
      tx_if.tx_active <= '0;
    end 
    else begin 
      clk_count <= clk_count;
      bit_index <= bit_index;
      tx_data <= tx_data;
      tx_if.tx_serial_out <= '0;
      tx_if.tx_done <= '0;
      tx_if.tx_active <= '1;
       
      case (state)
        IDLE : 		begin
          				tx_if.tx_serial_out   <= '1;         
                        tx_if.tx_done     <= '0;
                        clk_count <= '0;
                        bit_index   <= '0;
          				tx_active <= '1;

          			if (tx_if.tx_drive == 1) begin
                          tx_if.tx_active <= '1;
                          tx_data   <= tx_if.tx_byte_in;
                        end
                     end 


        TX_START : 	begin
                        tx_if.tx_serial_out <= '0;

          				if (clk_count < CLKS_PER_BIT-1) 	clk_count <= clk_count + 8'b1;
                        else								clk_count <= '0;
                     end 
         
        TX_DATA : 	begin
                        tx_if.tx_serial_out <= tx_data[bit_index];

                        if (clk_count < CLKS_PER_BIT-1) begin
                          clk_count <= clk_count +8'b1;
                        end
                        else begin
                          clk_count <= '0;

                          if (bit_index < 8) bit_index <= bit_index + 4'b1;
                        end
        			end
        
        TX_STOP :	begin
          				bit_index	<= '0;
                        tx_if.tx_serial_out <= '1;

       					if (clk_count < CLKS_PER_BIT-1) begin
                          clk_count <= clk_count + 8'b1;   
                        end
                        else begin
                          tx_if.tx_done     <= '1;
                          clk_count 		<= '0;
                          tx_if.tx_active   <= '0; 	
                       end
                    end 
        default	:	begin
          				clk_count 	<= 'x;
                        bit_index 	<= 'x;
                        tx_data 	<= 'x;
                        tx_if.tx_done 		<= 'x;
          				tx_if.tx_active 	<= 'x;
                        tx_if.tx_serial_out <= 'x;
                        
        			end
      endcase
    end
  end
   
endmodule : Uart_Tx

