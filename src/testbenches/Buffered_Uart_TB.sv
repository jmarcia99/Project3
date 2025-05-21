/* 
* Output Buffer and UART Transmitter Testbench
* Created By: Jordi Marcial Cruz
* Project: AES-128 Encryption Core
* Updated: May 10th, 2025
*
* Description:
* This testbench verifies the integration between the Output Buffer
* and UART Transmitter modules in the AES-128 Encryption Core system.
*
* The testbench includes:
* - A `Generator` class that produces both randomized and direct AES ciphertext test vectors.
* - A `Driver` class that writes 128-bit ciphertexts into the Output Buffer.
* - A `Monitor` class that reconstructs 128-bit text from UART serial output.
* - A `Scoreboard` class that compares DUT output with input stimuli.
*/

`include "BufferedUart.svh"
`timescale 1ns/10ps
 
import TestbenchPkg::*;

// =============================
// Packet class: Contains stimulus data
// =============================
class Packet extends TestbenchPkg::Packet;
  rand pkt_text_t text_pkt;

  function void f_create_packet (
 	input pkt_text_t text_pkt
  );
    this.text_pkt = text_pkt;
    this.pkt_count++;
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
  logic [7:0] serial_smpl;

  function new (logic [7:0] serial_smpl);
    this.serial_smpl = serial_smpl;
    this.smpl_count++;
    f_initial_report();
  endfunction

  function void f_initial_report();
    if (smpl_count == 16) begin 
      $display("[%0d][MON] All 16 Samples put into Monitor Mailbox", $stime);
      smpl_count = 0;
    end
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
  	input pkt_text_t text
  );
    $display("[%0d][GEN] Creating packet", $stime);
    pkt = new();
    pkt.f_create_packet(text);
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
  static int pkts_read;
  
  logic [0:15][7:0] assembled_smpl;
  int smpl_index;

  function new (
    mailbox driver_mbx,
    mailbox monitor_mbx
  );
    this.driver_mbx = driver_mbx;
    this.monitor_mbx = monitor_mbx;
    this.smpl_index = 0;
    this.errors = 0;
    this.pkts_read = 0;
    f_initial_report();
  endfunction
  
  function void f_initial_report(); 
    $display("Scoreboard instantiated in testbench");
  endfunction
  
  task t_check_results();
    if (pkt.text_pkt !== assembled_smpl) begin
      $display("[%0d][SB] Expected Text: %h, Received Text: %h", $stime, pkt.text_pkt, assembled_smpl);
      errors++;
    end else begin
      $display("[%0d][SB] Text Received matched Text Expected \n", $stime);
    end
    
    pkts_read++;
    smpl_index = 0;
    assembled_smpl = 0;
  endtask
    
  task t_run();
    forever begin
      driver_mbx.get(pkt);
      
      repeat(16) begin
      	monitor_mbx.get(smpl);
        assembled_smpl[smpl_index] = smpl.serial_smpl;
        smpl_index++;
      end
      
      t_check_results(); 
    end
  endtask
     
  function void f_final_report();
    if (errors > 0) 
      $display("[SB] Testbench FAILED with %0d errors!", errors);
    else if (pkts_read !== pkt.pkt_count) 
      $display("[SB] Testbench FAILED all packets not received!");
    else
      $display("[SB] Testbench PASSED with 0 errors! Received all %0d packets!", pkts_read); 
  endfunction
    
endclass : Scoreboard

// =============================
// Driver: Drives DUT interface
// ============================= 
class Driver extends TestbenchPkg::Driver;
  virtual Uart_Interface.Buffer_Driver uart_vif;
  Packet pkt;
  int debug;
  
  function new (
    virtual Uart_Interface.Buffer_Driver uart_vif,
    mailbox driver_mbx,
    mailbox generator_mbx
  );
    this.uart_vif = uart_vif;
    this.driver_mbx = driver_mbx;
    this.generator_mbx = generator_mbx;
    this.debug = 0;
    f_initial_report();
  endfunction
  
  function void f_initial_report(); 
    $display("Driver instantiated in testbench");
  endfunction
  
  task t_initialize_signals();
    `DRV_CB.text_in <= '0;
    `DRV_CB.buffer_write <= '0;
  endtask
  
  task t_run();
    forever begin 
      @(`DRV_CB);
      if (!`DRV_CB.buffer_full) begin 
        generator_mbx.get(pkt);
        driver_mbx.put(pkt); 
        `DRV_CB.text_in <= pkt.text_pkt;
        `DRV_CB.buffer_write <= '1;
        if (debug) $display("[%0d][DRV] Sent -> Text Data: %h", $stime, pkt.text_pkt);
        else	   $display("[%0d][DRV] Text Packet Sent", $stime);
        @(`DRV_CB);
        `DRV_CB.text_in <= '0;
        `DRV_CB.buffer_write <= '0;
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
            
            if (debug) $display("[%0d][MON] Received -> Serial Data: %h", $stime, return_shift_register);
            
            smpl = new(return_shift_register);
            monitor_mbx.put(smpl);
            
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
module Buffered_Uart_TB ();
  
  localparam CLOCK_PERIOD = 500; // 50 MHz clock
  localparam CLKS_PER_BIT = 434; // 50000000 / 115200 = 434 Clocks Per Bit.
  localparam DATA_WIDTH = 128;
   
  logic clk;
  logic reset_n;
  logic uart_serial_out;
  logic uart_buffer_full;
  logic text_ready;
  text_t cipher_text;
  
  Uart_Interface uart_if (.*);
   
  Uart_Tx #(
    .CLKS_PER_BIT		(CLKS_PER_BIT)
  ) Transmitter (
    .tx_if				(uart_if)
  );
  
  Output_Buffer #(
    .DATA_WIDTH 		(DATA_WIDTH)
  ) Buffer (
    .buff_if			(uart_if)
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
  
  task t_set_debug(input bit flag); 
    drv.debug = flag;
    mon.debug = flag;
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

  task t_send_text_pkt (input bit [DATA_WIDTH-1:0] text); 
    gen.t_create_pkt(text);
  endtask
  
  task t_send_randomized_text_pkts (input int num_of_pkts);
    gen.t_generate_pkts(num_of_pkts);
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
    drv = new(uart_if, driver_mbx, generator_mbx);
    mon = new(uart_if, CLKS_PER_BIT, monitor_mbx);
    $display("Beginning testbench, initializing signals...");
    t_reset_dut();
    t_set_debug(1);

    fork
      t_timeout(65000);
      t_run_processes();
    join_none

    $display("Beginning Direct Test Cases...");
    t_send_text_pkt(128'h000102030405060708090a0b0c0d0e0f);
    t_send_text_pkt(128'h00112233445566778899aabbccddeeff);
    
    $display("\nBeginning Random Test Cases...");
    t_send_randomized_text_pkts(30);
    
    repeat (3500) ##CLKS_PER_BIT;
    
    $display("\nBeginning Stress Test, bombarding output buffer...");
    t_set_debug(0);
    t_send_randomized_text_pkts(350); // Max fifo depth in output buffer is 128

    repeat (60000) ##CLKS_PER_BIT;
    sb.f_final_report();
    $finish;  
    
    end
endmodule




