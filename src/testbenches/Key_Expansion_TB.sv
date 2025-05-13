/* 
* AES-128 Key Expansion Testbench
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 10th, 2025
*
* Description:
* This testbench verifies the functionality of the AES-128 Key Expansion module. 
* It uses class-based architecture to model stimulus generation, driving logic, DUT monitoring, 
* and result checking. The testbench includes a reference model for expected key generation, 
* direct and randomized test scenarios, and a scoreboard to compare the outputs of the DUT with 
* the reference model. Testbench modules communicate through mailboxes and follow a layered
* structure for future modularity and reusability.
*/

`include "KeyExpansion.svh"
import TestbenchPkg::*;

// =============================
// Reference model for expected round keys
// =============================
class ReferenceModel extends RefModelPkg::KeyExpansion;
  function void f_initial_report();
    $display("Reference model created");
  endfunction

  function new();
    f_initial_report();
    f_set_debug();
  endfunction

  function void f_set_debug();
    this.debug_key_exp = 0;
    $display("---Debug set, showing all expected keys---");
  endfunction

  function void f_expand_round_key(input key_t key);
    this.key = key;
    this.round_key[0] = key;
    super.f_expand_key();
  endfunction
endclass : ReferenceModel

// =============================
// Packet class: Contains stimulus data
// =============================
class Packet extends TestbenchPkg::Packet;
  rand pkt_key_t key_pkt;

  function void f_create_packet(input pkt_key_t key_pkt);
    this.key_pkt = key_pkt;
  endfunction

  function void f_initial_report();
    $display("[%0d][GEN] Key generated", $stime);
  endfunction

  function void post_randomize();
    this.pkt_count++;
  endfunction
endclass : Packet

// =============================
// Sample class: Observed DUT output
// =============================
class Sample extends TestbenchPkg::Sample;
  rand smpl_key_t key_smpl;

  function new(smpl_key_t key_smpl);
    this.key_smpl = key_smpl;
    this.smpl_count++;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("[%0d][MON] Received Key : %h", $stime, key_smpl);
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
    $display("[%0d] Generating %0d randomized key packets", $stime, num_of_pkts);
    repeat (num_of_pkts) begin
      pkt = new();
      pkt.randomize();
      generator_mbx.put(pkt);
    end
    $display("[%0d] %0d Packets put into Generator Mailbox", $stime, num_of_pkts);
  endtask

  task t_create_pkt(input key_t key);
    $display("[%0d][GEN] Creating key packet", $stime);
    pkt = new();
    pkt.f_create_packet(key);
    generator_mbx.put(pkt);
    $display("[%0d][GEN] Packet put into Generator Mailbox", $stime);
  endtask
endclass : Generator

// =============================
// Scoreboard: Compares output with reference model
// =============================
class Scoreboard extends TestbenchPkg::Scoreboard;
  ReferenceModel ref_model;
  all_keys_t expected_round_key;
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

  function all_keys_t f_retreive_expected_keys(input key_t key);
    ref_model.f_expand_round_key(key);
    return ref_model.round_key;
  endfunction

  task t_check_results;
    expected_round_key = f_retreive_expected_keys(pkt.key_pkt);
    if (expected_round_key[10] !== smpl.key_smpl) begin
      $display("[%0d][SB] Expected Key: %h, Received Key: %h", $stime, expected_round_key[10], smpl.key_smpl);
      errors++;
    end else begin
      $display("[%0d][SB] Key Received matched Key Expected", $stime);
    end
  endtask

  task t_run();
    forever begin
      driver_mbx.get(pkt);
      monitor_mbx.get(smpl);
      t_check_results();
    end
  endtask

  function void f_final_report();
    if (errors > 0) $display("Testbench failed with %0d errors!", errors);
    else $display("Testbench passed with no errors!");
  endfunction
endclass : Scoreboard

// =============================
// Driver: Drives DUT interface
// =============================
class Driver extends TestbenchPkg::Driver;
  virtual AES_Core_Interface.Key_Exp_Driver aes_vif;
  Packet pkt;

  function new(virtual AES_Core_Interface.Key_Exp_Driver aes_vif, mailbox driver_mbx, mailbox generator_mbx);
    this.aes_vif = aes_vif;
    this.driver_mbx = driver_mbx;
    this.generator_mbx = generator_mbx;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("Driver instantiated in testbench");
  endfunction

  task t_initialize_signals();
    `DRV_CB.start_expansion <= 0;
    `DRV_CB.round <= 0;
    `DRV_CB.prev_key <= 0;
  endtask

  task t_run();
    forever begin
      repeat(10) @(`DRV_CB);
      generator_mbx.get(pkt);
      driver_mbx.put(pkt);
      $display("[%0d][DRV] Sending Key : %h", $stime, pkt.key_pkt);
      `DRV_CB.start_expansion <= 1;
      `DRV_CB.prev_key <= pkt.key_pkt;
      @(`DRV_CB);
      `DRV_CB.start_expansion <= 0;
      `DRV_CB.prev_key <= '0;
    end
  endtask
endclass : Driver

// =============================
// Monitor: Observes output from DUT
// =============================
class Monitor extends TestbenchPkg::Monitor;
  virtual AES_Core_Interface.Key_Exp_Monitor aes_vif;
  mailbox monitor_mbx;
  Sample smpl;

  function new(virtual AES_Core_Interface.Key_Exp_Monitor aes_vif, mailbox monitor_mbx);
    this.aes_vif = aes_vif;
    this.monitor_mbx = monitor_mbx;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("Monitor instantiated in testbench");
  endfunction

  task t_run();
    forever begin
      @(`MON_CB);
      if (`MON_CB.finished_expansion) begin
        smpl = new(`MON_CB.next_key);
        monitor_mbx.put(smpl);
      end
    end
  endtask
endclass : Monitor

// =============================
// Testbench Top Level
// =============================
module Key_Expansion_TB #(parameter DATA_WIDTH = 128);
  logic clk, reset_n;
  logic start_encryption;
  text_t plain_text;
  key_t original_key;
  text_t encrypted_text;
  logic finished_encryption;
  
  AES_Core_Interface aes_if (.*);
  Key_Expansion DUT (.kx_if(aes_if));

  mailbox generator_mbx;
  mailbox driver_mbx;
  mailbox monitor_mbx;
  ReferenceModel ref_model;
  Generator gen;
  Scoreboard sb;
  Driver dr;
  Monitor mon;

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

  task t_send_key(input key_t key);
    gen.t_create_pkt(key);
  endtask

  task t_send_randomized_keys(input int num_of_pkts);
    gen.t_generate_pkts(num_of_pkts);
  endtask

  initial begin
    clk = 1;
    forever #5 clk = ~clk;
  end

  default clocking cb @(posedge clk); endclocking

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
      t_timeout(15000);
      t_run_processes();
    join_none

    $display("Beginning Direct Test Cases...");
    t_send_key(128'h000102030405060708090A0B0C0D0E0F);
    t_send_key(128'h00000000000000000000000000000000);
    t_send_key(128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    t_send_key(128'h000102030405060708090A0B0C0D0E0F);

    $display("Beginning Randomized Test Cases...");
    t_send_randomized_keys(1500);

    ##12000;
    sb.f_final_report();
    $finish;
  end
endmodule : Key_Expansion_TB
