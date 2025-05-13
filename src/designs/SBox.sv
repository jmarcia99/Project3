/* 
* AES S-Box Lookup Module
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: March 22nd, 2025
*
* Description:
* This module implements the AES Substitution Box (S-Box) as a combinational lookup table.
* It instantiates 8 dual-port ROM blocks to provide parallel substitution of 16 input bytes
* at a time (8 ROMs x 2 ports).
*/

import DesignPkg::*;

module SBox (AES_Core_Interface.SBox sb_if);

  genvar a;
  generate
    // Instantiate 8 dual-port ROMs to handle 16 S-box lookups per cycle
    for (a = 0; a < 8; a++) begin : inst_sbox_tables
      DUAL_PORT_ROM #(
        .ADDR_WIDTH 	(8),             // 8-bit address (256 entries)
        .DATA_WIDTH 	(8),             // 8-bit output (substituted byte)
        .INIT       	("aes_sbox.mif") 
      ) sbox_table (
        .clock    		(sb_if.clk),                       
        .rden_a    		(1'b1),                            
        .address_a  	(sb_if.sbox_addr[a]),         
        .q_a  			(sb_if.sbox_value[a]),             
        .rden_b    		(1'b1),                            
        .address_b  	(sb_if.sbox_addr[a+8]),       
        .q_a  			(sb_if.sbox_value[a+8])           
      );
    end
  endgenerate

endmodule : SBox
