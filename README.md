# AES-128 Encryption Core
## Project Overview
This project is currently developing a fully functional AES-128 encryption core in SystemVerilog. The design includes all necessary components for encryption, such as the AES round logic and key expansion. It also features an AXI-Lite slave interface for memory-mapped control and a streaming output interface with a UART transmitter for serial data transmission of the encrypted data. The project is accompanied by a comprehensive class based verification environment with SystemVerilog Assertions to ensure the correctness and robustness of the design. 

| Category | Highlights |
|----------|------------|
| **AES Core** | 11‑round architecture, byte‑addressable state; independent Key Expansion module |
| **AXI‑Lite Slave** | Registered AW/W handshakes, single‑beat write/read, fixed OKAY response |
| **Streaming Output** | Depth‑128 FIFO; FSM controls byte hand‑off to UART |
| **UART Transmitter** | Parameterizable baud (`CLKS_PER_BIT`) with precise start/data/stop timing |
| **Verification** | Classes (Generator, Driver, Monitor, Scoreboard) + SVAs |

## RTL Module Summary
| Module | Purpose | Notable Details |
|--------|---------|-----------------|
| `AES_Controller` | Sequences encryption rounds, asserts `finished_encryption` | Round counter (0‑10) |
| `Key_Expansion`  | Generates next 128‑bit key each round | Rcon & S‑Box ROMs |
| `SBox`, `Shift_Rows`, `Mix_Columns` | Classical AES datapath | Combinational GF(2⁸) math |
| `AXI_Slave` | Memory‑mapped interface | Dual FSM (`wr_state`, `rd_state`) |
| `Output_Buffer` | 128‑bit FIFO + serializer | States: READ → WAIT → SEND |
| `Uart_Tx` | 8‑N‑1 transmitter | States: IDLE → START → DATA → STOP |
| Interfaces (`AES_Core_Interface`, `Uart_Interface`) | Type‑safe connectivity | Separate modports for TB & RTL |

## Verification Methodology
* **Reference models** (pure SV) for AES key expansion and encryption  
* **Constrained‑random** packet generation and stress tests (FIFO near‑full)  
* **SystemVerilog Assertions** bound via `Bindfiles.sv` check protocol handshakes, timing, and FSM legality  
* **Scoreboards** compare DUT output against golden model; automated pass/fail summary

