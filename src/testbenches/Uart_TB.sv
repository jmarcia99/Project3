/* 
* UART Transmitter Testbench
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: April 1st, 2025
*
* Description:
* This testbench verifies the functionality of a UART Transmitter module.
* It is structured using class-based components for generator, driver, monitor, scoreboard,
* and sample handling. Direct (non-randomized) test cases are used to validate correct UART
* serialization of fixed input data.
*
* This is an initial testbench for UART functionality. It serves as a foundational structure
* for more advanced UART testbenches, which may include randomized stimulus, error injection,
* and assertion-based verification in later stages.
*/

`include "UartTx.svh"
`timescale 1ns/10ps

import TestbenchPkg::*;

// =============================
// Packet class: Contains stimulus data
// =============================
class Packet extends TestbenchPkg::Packet;
  byte serial_pkt;
  
  function void f_initial_report(); 
    $display("[%0d] Packet generated", $stime);
  endfunction
  
  function void f_create_packet(input byte serial_pkt);
    this.serial_pkt = serial_pkt;
  endfunction
  
endclass : Packet

// =============================
// Sample class: Observed DUT output
// =============================
class Sample extends TestbenchPkg::Sample;
  logic [7:0] serial_smpl;

  function new (logic [7:0] serial_smpl);
    this.serial_smpl = serial_smpl;
    this.smpl_count++;
    f_initial_report();
  endfunction

  function void f_initial_report();
    $display("[%0d][MON] Sample put into Monitor Mailbox", $stime);
  endfunction

endclass : Sample

// =============================
// Generator class: Produces test packets
// =============================
class Generator extends TestbenchPkg::Generator;
  Packet pkt;
  
  function new (mailbox generator_mbx);
    this.generator_mbx = generator_mbx;
    f_initial_report();
  endfunction
  
  function void f_initial_report(); 
    $display("Generator instantiated in testbench");
  endfunction
  
  task t_generate_pkts(input int num_of_pkts);
    // Not to be used in this testbench
  endtask

  task t_create_pkt(input byte serial_pkt);
    $display("[%0d][GEN] Creating serial packet", $stime);
    pkt = new();
    pkt.f_create_packet(serial_pkt);
    generator_mbx.put(pkt);
    $display("[%0d][GEN] Packet put into Generator Mailbox", $stime);
  endtask
endclass : Generator

// =============================
// Scoreboard: Compares output 
// =============================
class Scoreboard extends TestbenchPkg::Scoreboard;
  Packet pkt;
  Sample smpl;

  function new (
    mailbox driver_mbx,
    mailbox monitor_mbx
  );
    this.driver_mbx = driver_mbx;
    this.monitor_mbx = monitor_mbx;
    this.errors = 0;
    f_initial_report();
  endfunction
  
  function void f_initial_report(); 
    $display("Scoreboard instantiated in testbench");
  endfunction
  
  task t_check_results();
    if (pkt.serial_pkt !== smpl.serial_smpl) begin
      $error("[%0d][SB] Expected Serial Data: %h, Received Serial Data: %h", $stime, pkt.serial_pkt, smpl.serial_smpl);
      errors++;
    end else begin
      $display("[%0d][SB] Serial Data Received matched Expected Serial Data", $stime);
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
    if (errors > 0) 
        $display("[SB] Test FAILED with %0d errors!", errors);
    else 
        $display("[SB] Test PASSED with 0 errors!");
  endfunction
    
endclass : Scoreboard

// =============================
// Driver: Drives DUT interface
// =============================
class Driver extends TestbenchPkg::Driver;
  virtual Uart_Interface.Tx_Driver uart_vif;
  const int CLKS_PER_BIT;
  Packet pkt;
  int debug; 
  
  function new (
    virtual Uart_Interface.Tx_Driver uart_vif,
    int CLKS_PER_BIT,
    mailbox driver_mbx,
    mailbox generator_mbx
  );
    this.uart_vif = uart_vif;
    this.driver_mbx = driver_mbx;
    this.generator_mbx = generator_mbx;
    this.CLKS_PER_BIT = CLKS_PER_BIT;
    this.debug = 0;
    f_initial_report();
  endfunction
  
  function void f_initial_report(); 
    $display("Driver instantiated in testbench");
  endfunction
  
  task t_initialize_signals();
    `DRV_CB.tx_drive <= '0;
    `DRV_CB.tx_byte_in <= '0;
  endtask
  
  task t_run();
    forever begin 
      @(`DRV_CB);
      if (!`DRV_CB.tx_active) begin 
        generator_mbx.get(pkt);
        driver_mbx.put(pkt);
        `DRV_CB.tx_drive <= '1;
        `DRV_CB.tx_byte_in <= pkt.serial_pkt; 
        if (debug) $display("[%0d][Driver] Sent -> Serial Data: %h", $stime, pkt.serial_pkt);
        @(`DRV_CB);
        `DRV_CB.tx_drive <= '0; 
        `DRV_CB.tx_byte_in <= '0;
      	@(`DRV_CB);
      end
    end
  endtask
    
endclass : Driver 

// =============================
// Monitor: Observes output from DUT
// =============================
class Monitor extends TestbenchPkg::Monitor;
  virtual Uart_Interface.Tx_Monitor uart_vif;
  const int CLKS_PER_BIT;
  Sample smpl;
  
  logic [7:0] return_shift_register;
  int debug;
  
  function new (
    virtual Uart_Interface.Tx_Monitor uart_vif,
    int CLKS_PER_BIT,
    mailbox monitor_mbx
  );
    this.uart_vif = uart_vif;
    this.monitor_mbx = monitor_mbx;
    this.return_shift_register = '0;
    this.CLKS_PER_BIT = CLKS_PER_BIT;
    this.debug = 0;
    f_initial_report();
  endfunction 
  
  function void f_initial_report(); 
    $display("Monitor instantiated in testbench");
  endfunction
  
  task t_run();
    forever begin 
      if (`MON_CB.tx_active) begin 
        @(`MON_CB);
        
        fork 
          begin 
            repeat(CLKS_PER_BIT) @(`MON_CB);
          
            repeat(8) begin 
              return_shift_register[7:0] <= {`MON_CB.tx_serial_out, return_shift_register[7:1]};
              repeat(CLKS_PER_BIT) @(`MON_CB);
            end 
            
            return_shift_register <= return_shift_register;
            @(`MON_CB);
            
            smpl = new(return_shift_register);
            monitor_mbx.put(smpl);
            
            if (debug) $display("[%0d][MON] Received -> Serial Data: %h", $stime, return_shift_register); 
          end

          begin 
            while (!`MON_CB.tx_done) @(`MON_CB);
          end
        join
        
      end
      else begin 
        @(`MON_CB);
      end
    end
  endtask
    
endclass : Monitor 
  
// ============================= 
// Testbench Top Level
// =============================
module Uart_TB ();
  
  localparam CLOCK_PERIOD = 500; // 50 MHz clock
  localparam CLKS_PER_BIT = 434; // 50000000 / 115200 = 434 Clocks Per Bit.
  localparam DATA_WIDTH = 128;
   
  logic clk;
  logic reset_n;
  logic uart_serial_out;
  logic uart_buffer_full;
  logic text_ready;
  text_t cipher_text;
  
  logic [7:0] return_shift_register = '0;
  
  Uart_Interface uart_if (.*);
   
  Uart_Tx #(
    .CLKS_PER_BIT		(CLKS_PER_BIT)
  ) Transmitter (
    .tx_if				(uart_if)
  );
  
  mailbox generator_mbx;
  mailbox driver_mbx;
  mailbox monitor_mbx;
  Generator gen;
  Scoreboard sb;
  Driver drv;
  Monitor mon;

  task t_reset_dut();
    reset_n = 0;
    drv.t_initialize_signals();
    #5;
    reset_n = 1;
  endtask
  
  task t_set_debug(); 
    drv.debug = 1;
    mon.debug = 1;
  endtask

  task t_run_processes();
    fork
      drv.t_run();
      mon.t_run();
      sb.t_run();
    join_none
  endtask

  task t_timeout(input int cycles);
    repeat(cycles * CLKS_PER_BIT) @(posedge clk);
    $fatal("Testbench timed out");
  endtask

  task t_send_serial_data (input byte serial_data);
    gen.t_create_pkt(serial_data);
  endtask
  
  default clocking cb @(posedge clk); endclocking
 
  initial begin 
    clk = 1;
    forever #(CLOCK_PERIOD/2) clk = ~clk;
  end
   
  // Main Testing:
  initial begin 
    driver_mbx = new;
    monitor_mbx = new;
    generator_mbx = new;
    gen = new(generator_mbx);
    sb = new(driver_mbx, monitor_mbx);
    drv = new(uart_if, CLKS_PER_BIT, driver_mbx, generator_mbx);
    mon = new(uart_if, CLKS_PER_BIT, monitor_mbx);
    $display("Beginning testbench, initializing signals...");
    t_reset_dut();

    fork
      t_timeout(10000);
      t_run_processes();
    join_none

    $display("Beginning Direct Test Cases...");
    t_send_serial_data(8'hAA);
    t_send_serial_data(8'h47);
    t_send_serial_data(8'h0F); 
    t_send_serial_data(8'hD0);
    t_send_serial_data(8'h00);
    t_send_serial_data(8'hFF); 
    
    repeat (1000) ##CLKS_PER_BIT;
    sb.f_final_report();
    $finish;
    
    end
endmodule




