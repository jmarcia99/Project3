/* 
* AES-128 Encryption Core Testbench
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 25th, 2025
*
* Description:
* This SystemVerilog testbench verifies the functionality of the AES-128 Encryption Core.
* It instantiates all datapath and control modules (Key Expansion, SBox, ShiftRows, MixColumns,
* and Controller), drives input stimulus, monitors DUT output, and compares results against
* a golden reference model. It supports both fixed test vectors and randomized test cases,
* and uses a class-based architecture for modular and reusable verification components.
*/

`include "AES_Core.svh"

import TestbenchPkg::*;

// =============================
// Reference model for expected encypted text
// =============================
class ReferenceModel extends RefModelPkg::TextEncryption;
  
  function void f_initial_report();
    $display("Reference model created");
  endfunction
  
  function new();
    f_initial_report();
  endfunction 
  
  function void f_set_debug();
    this.debug_key_exp = 0;
    $display("---Debug set, showing all expected keys---");
  endfunction
  
  function void f_encrypt_plain_text (
    input key_t original_key,
    input key_t plain_text
  );
    this.key = original_key;
    this.round_key[0] = original_key;
    this.state_text = plain_text;
    super.f_expand_key(); 
    super.f_encrypt_text();
  endfunction 
 
endclass : ReferenceModel

// =============================
// Packet class: Contains stimulus data
// =============================
class Packet extends TestbenchPkg::Packet;
  rand pkt_key_t key_pkt;
  rand pkt_text_t text_pkt;

  function void f_create_packet (
    input pkt_key_t key_pkt,
 	input pkt_text_t text_pkt
  );
    this.key_pkt = key_pkt;
    this.text_pkt = text_pkt;
  endfunction

  function void f_initial_report();
    $display("[%0d][GEN] Packet generated", $stime);
  endfunction

  function void post_randomize();
    this.pkt_count++;
  endfunction
endclass : Packet

// =============================
// Sample class: Observed DUT output
// =============================
class Sample extends TestbenchPkg::Sample;
  rand smpl_text_t text_smpl;

  function new(smpl_key_t text_smpl);
    this.text_smpl = text_smpl;
    this.smpl_count++;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("[%0d][MON] Received -> Encrypted Text : %h", $stime, text_smpl);
  endfunction
  
endclass : Sample

// =============================
// Generator class: Produces test packets
// =============================
class Generator extends TestbenchPkg::Generator;
  Packet pkt;

  function new(mailbox generator_mbx);
    this.generator_mbx = generator_mbx;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("Generator instantiated in testbench");
  endfunction

  task t_generate_pkts(input int num_of_pkts);
    $display("[%0d] Generating %0d randomized packets", $stime, num_of_pkts);
    repeat (num_of_pkts) begin
      pkt = new();
      pkt.randomize();
      generator_mbx.put(pkt);
    end
    $display("[%0d] %0d Packets put into Generator Mailbox", $stime, num_of_pkts);
  endtask

  task t_create_pkt (
  	input pkt_key_t key,
  	input pkt_text_t text
  );
    $display("[%0d][GEN] Creating packet", $stime);
    pkt = new();
    pkt.f_create_packet(key, text);
    generator_mbx.put(pkt);
    $display("[%0d][GEN] Packet put into Generator Mailbox", $stime);
  endtask
endclass : Generator

// =============================
// Scoreboard: Compares output with reference model
// =============================
class Scoreboard extends TestbenchPkg::Scoreboard;
  ReferenceModel ref_model;
  smpl_text_t expected_text;
  Packet pkt;
  Sample smpl;

  function new(ReferenceModel ref_model, mailbox driver_mbx, mailbox monitor_mbx);
    this.ref_model = ref_model;
    this.driver_mbx = driver_mbx;
    this.monitor_mbx = monitor_mbx;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("Scoreboard instantiated in testbench");
  endfunction
  
  task t_run();
    forever begin
      driver_mbx.get(pkt);
      monitor_mbx.get(smpl);
      t_check_results();
    end
  endtask
  
  task t_check_results();
    expected_text = f_retreive_expected_text(pkt.key_pkt, pkt.text_pkt);
    
    if (expected_text !== smpl.text_smpl) begin
      $display("[%0d][SB] Expected Text: %h, Received Text: %h", $stime, expected_text, smpl.text_smpl);
      errors++;
    end else begin
      $display("[%0d][SB] Text Received matched Text Expected \n", $stime);
    end
  endtask
  
  function pkt_text_t f_retreive_expected_text (
    input pkt_key_t key,
    input pkt_text_t text
  );
    ref_model.f_encrypt_plain_text(key, text);
    
    return ref_model.state_text;
  endfunction

  function void f_final_report();
    if (errors > 0) $display("Testbench failed with %0d errors!", errors);
    else $display("Testbench passed with no errors!");
  endfunction
endclass : Scoreboard
 

// =============================
// Driver: Drives DUT interface
// =============================
class Driver extends TestbenchPkg::Driver;
  virtual AES_Core_Interface.AES_Driver aes_vif;
  Packet pkt;
  
  function new (
  	virtual AES_Core_Interface.AES_Driver aes_vif,
    mailbox driver_mbx,
    mailbox generator_mbx
  );
    this.aes_vif = aes_vif;
    this.driver_mbx = driver_mbx;
    this.generator_mbx = generator_mbx;
  endfunction

  function void f_initial_report();
    $display("Driver instantiated in testbench");
  endfunction

  task t_initialize_signals();
    `DRV_CB.start_encryption <= 0;
    `DRV_CB.plain_text <= 0;
    `DRV_CB.original_key <= 0;
  endtask

  // Randomize Control Sigals and delay
  task t_run();
    forever begin
      repeat(12) @(`DRV_CB);
      generator_mbx.get(pkt);
      driver_mbx.put(pkt);
      `DRV_CB.start_encryption <= 1;
      `DRV_CB.plain_text <= pkt.text_pkt;
      `DRV_CB.original_key <= pkt.key_pkt;
      $display("[%0d][DRV] Sending -> Key: %h, Plain Text: %h", $stime, pkt.key_pkt, pkt.text_pkt);
      @(`DRV_CB);
      `DRV_CB.start_encryption <= 0;
      `DRV_CB.plain_text <= 0;
      `DRV_CB.original_key <= 0;
    end
  endtask
  
endclass : Driver

// =============================
// Monitor: Observes output from DUT
// =============================
class Monitor extends TestbenchPkg::Monitor;
  virtual AES_Core_Interface.AES_Monitor aes_vif;
  Sample smpl;
  
  function new (
    virtual AES_Core_Interface.AES_Monitor aes_vif,
    mailbox monitor_mbx
  );
    this.aes_vif = aes_vif;
    this.monitor_mbx = monitor_mbx;
  endfunction

  function void f_initial_report();
    $display("Monitor instantiated in testbench");
  endfunction

  task t_run();
    forever begin
      @(`MON_CB);
      if (`MON_CB.finished_encryption) begin
        smpl = new(`MON_CB.encrypted_text);
        monitor_mbx.put(smpl);
      end
    end
  endtask
endclass : Monitor

// =============================
// Testbench Top Level
// =============================
module AES_Core_TB
  #(parameter DATA_WIDTH = 128);
    
  logic clk, reset_n;
  logic start_encrypt;
  logic output_buffer_full;
  text_t provided_text;
  key_t provided_key;
  
  text_t final_text;
  logic finished_encrypt;
  
  mailbox driver_mbx;
  mailbox monitor_mbx;
  mailbox generator_mbx;
  ReferenceModel ref_model;
  Generator gen;
  Scoreboard sb;
  Monitor mon;
  Driver dr;
  
  AES_Core_Interface aes_if (.*);
  
  Key_Expansion Key_Exp (
    .kx_if			(aes_if)
  );
  
  SBox SBox_Tables (
    .sb_if			(aes_if)
  );
  
  Shift_Rows Shift_Rows (
    .sr_if			(aes_if) 
  );
  
  Mix_Columns Mix_Columns (
    .mc_if			(aes_if)
  );
  
  AES_Controller Controller (
    .cntrl_if		(aes_if)
  );
  
  task t_reset_dut();
    reset_n = 0;
    dr.t_initialize_signals();
    #5;
    reset_n = 1;
  endtask

  task t_run_processes();
    fork
      sb.t_run();
      dr.t_run();
      mon.t_run();
    join_none
  endtask

  task t_timeout(input int cycles);
    repeat(cycles) @(posedge clk);
    $fatal("Testbench timed out");
  endtask

  task t_send_key_and_text (
    input key_t key,
  	input text_t text
  );
    gen.t_create_pkt(key, text);
  endtask

  task t_send_randomized_pkts(input int num_of_pkts);
    gen.t_generate_pkts(num_of_pkts);
  endtask
  
  default clocking @(posedge clk); endclocking
  
  initial begin 
    clk = 1;
    forever #5 clk = ~clk;
  end
	
  initial begin 
    ref_model = new;
    driver_mbx = new;
    monitor_mbx = new;
    generator_mbx = new;
    gen = new(generator_mbx);
    sb = new(ref_model, driver_mbx, monitor_mbx);
    dr = new(aes_if, driver_mbx, generator_mbx);
    mon = new(aes_if, monitor_mbx);
    
    $display("Beginning testbench, initializing signals...");
    t_reset_dut();

    fork
      t_timeout(1000000);
      t_run_processes();
    join_none

    // Test vectors from CSRC
    $display("Beginning Direct Test Cases...");
    t_send_key_and_text(128'h000102030405060708090a0b0c0d0e0f, 128'h00112233445566778899aabbccddeeff);
    t_send_key_and_text(128'h139a35422f1d61de3c91787fe0507afd, 128'hb9145a768b7dc489a096b546f43b231f);
    t_send_key_and_text(128'hc459caeebf2c42586c01666a9334b97b, 128'hd7c3ffac9031238650901e157364c386);
    t_send_key_and_text(128'h786ffd349283cd971069dd42527719df, 128'hbc3637da2daf8fcf7c68bb28c143a0a4);
    t_send_key_and_text(128'he4e755efeb0c85480aad4e28a8e28773, 128'h9c88a8db798f48df1ac4936afa959eac);
    t_send_key_and_text(128'h2573ded4a95abd8ab3250cecebc5bb29, 128'h79ee212734f14d1bf5a59d46e8c2fa34);
    t_send_key_and_text(128'he98ef4285586a1b458427105b4712e42, 128'hc52263efa6379209d17e87ac250615cb);
    t_send_key_and_text(128'hdae519292b9603f3b6d0e99dd6323f21, 128'h336bed017e10a247ee92989862431163);
    t_send_key_and_text(128'h6bd60971346858e31c3f37254f18d339, 128'hb13310581ffe5b10aaefdeb8992aec18);
    t_send_key_and_text(128'hdb3ce492c786e70c94bd1d4b91018388, 128'hb0eaede3f3eebfef88822a6ede1950b1);
    
    ##150;
    
    // Data Path Only 
    $display("\nBeginning Randomized Test Cases...");
    t_send_randomized_pkts(1000);

    ##14000;
    
    // Note: Need to randomize control signals, expand packet class for this

    sb.f_final_report();
  end 

endmodule : AES_Core_TB


