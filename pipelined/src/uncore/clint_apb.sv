///////////////////////////////////////////
// clint_apb.sv
//
// Written: David_Harris@hmc.edu 14 January 2021
// Modified: 
//
// Purpose: Core-Local Interruptor
//   See FE310-G002-Manual-v19p05 for specifications
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module clint_apb (
  input  logic             PCLK, PRESETn,
  input  logic             PSEL,
  input  logic [15:0]      PADDR, 
  input  logic [`XLEN-1:0] PWDATA,
  input  logic [`XLEN/8-1:0] PSTRB,
  input  logic             PWRITE,
  input  logic             PENABLE,
  output logic [`XLEN-1:0] PRDATA,
  output logic             PREADY,
  (* mark_debug = "true" *) output logic [63:0] MTIME, 
  output logic 			   MTimerInt, MSwInt);

  logic        MSIP;

  logic [15:0] entry;
  logic memwrite;
   (* mark_debug = "true" *)    logic [63:0] MTIMECMP;
  integer             i, j;
  
  assign memwrite = PWRITE & PENABLE & PSEL;  // only write in access phase
  assign PREADY = 1'b1; // GPIO never takes >1 cycle to respond

  // word aligned reads
  if (`XLEN==64) assign #2 entry = {PADDR[15:3], 3'b000};
  else           assign #2 entry = {PADDR[15:2], 2'b00}; 
  
  //swbytemask swbytemask(.Size(HSIZED[1:0]), .Adr(entry[2:0]), .ByteMask(PSTRB));

  // DH 2/20/21: Eventually allow MTIME to run off a separate clock
  // This will require synchronizing MTIME to the system clock
  // before it is read or compared to MTIMECMP.
  // It will also require synchronizing the write to MTIMECMP.
  // Use req and ack signals synchronized across the clock domains.

  // register access
  if (`XLEN==64) begin:clint // 64-bit
    always @(posedge PCLK) begin
      case(entry)
        16'h0000: PRDATA <= {63'b0, MSIP};
        16'h4000: PRDATA <= MTIMECMP;
        16'hBFF8: PRDATA <= MTIME;
        default:  PRDATA <= 0;
      endcase
    end 
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MSIP <= 0;
        MTIMECMP <= 64'hFFFFFFFFFFFFFFFF; // Spec says MTIMECMP is not reset, but we reset to maximum value to prevent spurious timer interrupts
      end else if (memwrite) begin
        if (entry == 16'h0000) MSIP <= PWDATA[0];
        if (entry == 16'h4000) begin
          for(i=0;i<`XLEN/8;i++)
            if(PSTRB[i])
              MTIMECMP[i*8 +: 8] <= PWDATA[i*8 +: 8]; // ***dh: this notation isn't in book yet - maybe from Ross
        end
      end

// eventually replace MTIME logic below with timereg
//    timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), 1'b0, PWDATA, MTIME, done);

    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MTIME <= 0;
      end else if (memwrite & entry == 16'hBFF8) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(j=0;j<`XLEN/8;j++)
          if(PSTRB[j])
            MTIME[j*8 +: 8] <= PWDATA[j*8 +: 8];
      end else MTIME <= MTIME + 1; 
  end else begin:clint // 32-bit
    always @(posedge PCLK) begin
      case(entry)
        16'h0000: PRDATA <= {31'b0, MSIP};
        16'h4000: PRDATA <= MTIMECMP[31:0];
        16'h4004: PRDATA <= MTIMECMP[63:32];
        16'hBFF8: PRDATA <= MTIME[31:0];
        16'hBFFC: PRDATA <= MTIME[63:32];
        default:  PRDATA <= 0;
      endcase
    end 
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MSIP <= 0;
        MTIMECMP <= 0;
        // MTIMECMP is not reset ***?
      end else if (memwrite) begin
        if (entry == 16'h0000) MSIP <= PWDATA[0];
        if (entry == 16'h4000) 
          for(j=0;j<`XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[j*8 +: 8] <= PWDATA[j*8 +: 8];
        if (entry == 16'h4004) 
          for(j=0;j<`XLEN/8;j++)
            if(PSTRB[j])
              MTIMECMP[32 + j*8 +: 8] <= PWDATA[j*8 +: 8];
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
      end

// eventually replace MTIME logic below with timereg
//     timereg tr(PCLK, PRESETn, TIMECLK, memwrite & (entry==16'hBFF8), memwrite & (entry == 16'hBFFC), PWDATA, MTIME, done);
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) begin
        MTIME <= 0;
        // MTIMECMP is not reset
      end else if (memwrite & (entry == 16'hBFF8)) begin
        for(i=0;i<`XLEN/8;i++)
          if(PSTRB[i])
            MTIME[i*8 +: 8] <= PWDATA[i*8 +: 8];
      end else if (memwrite & (entry == 16'hBFFC)) begin
        // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
        for(i=0;i<`XLEN/8;i++)
          if(PSTRB[i])
            MTIME[32 + i*8 +: 8]<= PWDATA[i*8 +: 8];
      end else MTIME <= MTIME + 1;
  end 

  // Software interrupt when MSIP is set
  assign MSwInt = MSIP;
  // Timer interrupt when MTIME >= MTIMECMP
  assign MTimerInt = ({1'b0, MTIME} >= {1'b0, MTIMECMP}); // unsigned comparison

endmodule

module timeregsync(
  input  logic clk, resetn, 
  input  logic             we0, we1,
  input  logic [`XLEN-1:0] wd,
  output logic [63:0]      q);

  if (`XLEN==64) 
    always_ff @(posedge clk or negedge resetn) 
      if (~resetn) q <= 0;
      else if (we0) q <= wd;
      else          q <= q + 1;
  else
    always_ff @(posedge clk or negedge resetn) 
      if (~resetn) q <= 0;
      else if (we0) q[31:0] <= wd;
      else if (we1) q[63:32] <= wd;
      else          q <= q + 1;
endmodule

module timereg(
  input  logic PCLK, PRESETn, TIMECLK,
  input  logic             we0, we1,
  input  logic [`XLEN-1:0] PWDATA,
  output logic [63:0]      MTIME,
  output logic             done);

//  if (`TIMEBASE_SYNC) begin:timereg // use PCLK for MTIME
  if (1) begin:timereg // use PCLK for MTIME
    timregsync timeregsync(.clk(PCLK), .resetn(PRESETn), .we0, .we1, .wd(PWDATA), .q(MTIME));
    assign done = 1; // immediately completes
  end else begin // use asynchronous TIMECLK 
    // TIME counter runs on TIMECLK but bus interface runs on PCLK
    // Need to synchronize reads and writes
    // This is subtle because synchronizing a binary counter on a per-bit basis could give a mix of old and new bits
    // Instead, we use a Gray coded counter that only changes one bit per cycle
    // Synchronizing this for a read is safe because we are guaranteed to get either the old or the new value.
    // Writing to the counter requires a request/acknowledge handshake to ensure the write value is held long enough.
    // The handshake signals are synchronized in each direction across the interface
    // There is no back pressure on instructions, so if multiple counter writes occur ***

    logic req, req_sync, ack, we0_stored, we1_stored, ack_stored, resetn_sync;
    logic [`XLEN-1:0] wd_stored;
    logic [63:0] time_int, time_int_gc, time_gc, MTIME_GC;

    // When a write enable is asserted for a cycle, sample the enables and data and raise a request until it is acknowledged
    // When the acknowledge falls, the transaction is done and the system is ready for another write.
    // ***look at redoing this assuming write enable and data are held rather than pulsed.
    always_ff @(posedge PCLK or negedge PRESETn) 
      if (~PRESETn) 
        req <= 0; // don't bother resetting wd
      else begin
        req        <= we0 | we1 | req & ~ack;
        we0_stored <= we0; 
        we1_stored <= we1;
        wd_stored  <= PWDATA;
        ack_stored <= ack;
        done       <= ack_stored & ~ack;
      end

    // synchronize the reset and reqest into the TIMECLK domain
    sync resetsync(TIMECLK, PRESETn, resetn_sync);
    sync rsync(TIMECLK, req, req_sync);
    // synchronize the acknowledge back to the PCLK domain to indicate the request was handled and can be lowered
    sync async(PCLK, req_sync, ack);

    timeregsync timeregsync(.clk(TIMECLK), .resetn(resetn_sync), .we0(we0_stored), .we1(we1_stored), .wd(wd_stored), .q(time_int));
    binarytogray b2g(time_int, time_int_gc);
    flop gcreg(TIMECLK, time_int_gc, time_gc);

    sync timesync[63:0](PCLK, time_gc, MTIME_GC); 
    graytobinary g2b(MTIME_GC, MTIME);
  end
endmodule

module binarytogray #(parameter N = `XLEN) (
  input  logic [N-1:0] b,
  output logic [N-1:0] g);

  // G[N-1] = B[N-1]; G[i] = B[i] ^ B[i+1] for 0 <= i < N-1
  // requires single layer of N-1 XOR gates
  assign g = b ^ {1'b0, b[N-1:1]};
endmodule

module graytobinary #(parameter N = `XLEN) (
  input  logic [N-1:0] g,
  output logic [N-1:0] b);

  // B[N-1] = G[N-1]; B[i] = G[i] ^ B[i+1] for 0 <= i < N-1
  // requires rippling through N-1 XOR gates
    genvar i;
    assign b[N-1] = g[N-1];
    for (i=N-2; i >= 0; i--) begin:g2b
      assign b[i] = g[i] ^ b[i+1];
    end
endmodule