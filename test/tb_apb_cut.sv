//-----------------------------------------------------------------------------
// Copyright (C) 2026 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
// SPDX-License-Identifier: SHL-0.51
//-----------------------------------------------------------------------------

// Testbench for apb_cut: a random APB master drives the target side, a random
// APB slave (with random wait states) sits on the initiator side. Every request
// issued by the master must reach the slave exactly once and unchanged, every
// read response returned by the slave must reach the master unchanged, and the
// slave must never observe more completed transfers than the master issued
// (the classic bug of a response-only register: a spurious second access phase
// after pready).

`include "apb/assign.svh"

module tb_apb_cut #(
  parameter int unsigned  ApbAddrWidth = 32'd32,
  parameter int unsigned  ApbDataWidth = 32'd32,
  parameter bit           Bypass       = 1'b0,
  localparam int unsigned ApbStrbWidth = cc_pkg::ceil_div(ApbDataWidth, 8),

  // TB Parameters
  parameter time          TCLK = 10ns,
  parameter time          TA = TCLK * 1/4,
  parameter time          TT = TCLK * 3/4,
  parameter int unsigned  REQ_MIN_WAIT_CYCLES  = 0,   // 0 -> back-to-back transfers
  parameter int unsigned  REQ_MAX_WAIT_CYCLES  = 6,
  parameter int unsigned  RESP_MIN_WAIT_CYCLES = 0,
  parameter int unsigned  RESP_MAX_WAIT_CYCLES = 5,
  parameter int unsigned  N_TXNS = 1000
);
  logic clk;
  logic rst_n;

  clk_rst_gen #(
    .ClkPeriod    (TCLK),
    .RstClkCycles (5)
  ) i_clk_rst_gen (
    .clk_o  (clk),
    .rst_no (rst_n)
  );

  // Target side (upstream master) ---------------------------------------------
  APB_DV #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) source_bus_dv(clk);

  APB #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) source_bus();
  `APB_ASSIGN(source_bus, source_bus_dv)

  // Initiator side (downstream slave) ------------------------------------------
  APB_DV #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) sink_bus_dv(clk);

  APB #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) sink_bus();
  `APB_ASSIGN(sink_bus_dv, sink_bus)

  typedef apb_test::apb_request #(.ADDR_WIDTH(ApbAddrWidth), .DATA_WIDTH(ApbDataWidth)) apb_request_t;
  typedef apb_test::apb_response #(.DATA_WIDTH(ApbDataWidth)) apb_response_t;

  // DUT ------------------------------------------------------------------------
  apb_cut_intf #(
    .BYPASS         ( Bypass       ),
    .APB_ADDR_WIDTH ( ApbAddrWidth ),
    .APB_DATA_WIDTH ( ApbDataWidth )
  ) i_dut (
    .clk_i     ( clk        ),
    .rst_ni    ( rst_n      ),
    .target    ( source_bus ),
    .initiator ( sink_bus   )
  );

  // Master -----------------------------------------------------------------------
  apb_test::apb_rand_master #(
    .ADDR_WIDTH          ( ApbAddrWidth        ),
    .DATA_WIDTH          ( ApbDataWidth        ),
    .TA                  ( TA                  ),
    .TT                  ( TT                  ),
    .REQ_MIN_WAIT_CYCLES ( REQ_MIN_WAIT_CYCLES ),
    .REQ_MAX_WAIT_CYCLES ( REQ_MAX_WAIT_CYCLES )
  ) apb_master = new(source_bus_dv);

  logic mst_done = 1'b0;
  initial begin
    wait(rst_n);
    apb_master.run(N_TXNS);
    mst_done = 1'b1;
  end

  // Slave ------------------------------------------------------------------------
  apb_test::apb_rand_slave #(
    .ADDR_WIDTH           ( ApbAddrWidth         ),
    .DATA_WIDTH           ( ApbDataWidth         ),
    .TA                   ( TA                   ),
    .TT                   ( TT                   ),
    .RESP_MIN_WAIT_CYCLES ( RESP_MIN_WAIT_CYCLES ),
    .RESP_MAX_WAIT_CYCLES ( RESP_MAX_WAIT_CYCLES )
  ) apb_slave = new(sink_bus_dv);

  initial begin
    wait(rst_n);
    apb_slave.run();
  end

  // Protocol monitors ------------------------------------------------------------
  // Completed transfers on each side: psel & penable & pready. The slave side
  // must never run ahead of the master side, and the two totals must match.
  int unsigned mst_xfers = 0;
  int unsigned slv_xfers = 0;
  int unsigned errors    = 0;

  always @(posedge clk) begin
    if (rst_n) begin
      #TT;
      if (source_bus_dv.psel && source_bus_dv.penable && source_bus_dv.pready) mst_xfers++;
      if (sink_bus_dv.psel   && sink_bus_dv.penable   && sink_bus_dv.pready)   slv_xfers++;
      assert (slv_xfers <= mst_xfers + 1) else begin
        $error("Slave side completed %0d transfers while the master side completed %0d: spurious transfer.",
               slv_xfers, mst_xfers);
        errors++;
      end
    end
  end

  // The initiator side must show a legal setup phase (psel & !penable) exactly one
  // cycle before every access phase, and never an access phase without psel.
  logic sink_psel_q, sink_penable_q;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sink_psel_q    <= 1'b0;
      sink_penable_q <= 1'b0;
    end else begin
      // Sample at the test time, like the drivers do.
      #TT;
      assert (!(sink_bus_dv.penable && !sink_bus_dv.psel)) else begin
        $error("Initiator side: penable without psel."); errors++;
      end
      assert (!(sink_bus_dv.psel && sink_bus_dv.penable && !sink_penable_q) || (sink_psel_q && !sink_penable_q)) else begin
        $error("Initiator side: access phase not preceded by a one-cycle setup phase."); errors++;
      end
      sink_psel_q    <= sink_bus_dv.psel;
      sink_penable_q <= sink_bus_dv.penable;
    end
  end

  // Scoreboard -------------------------------------------------------------------
  // Requests are issued and served strictly in order (APB is sequential), so the
  // master and slave queues line up one to one.
  localparam int unsigned MAX_LATENCY_CYCLES = 4 + RESP_MAX_WAIT_CYCLES;

  initial begin
    automatic apb_request_t  expected_request  = new;
    automatic apb_request_t  received_request  = new;
    automatic apb_response_t received_response = new;
    automatic apb_response_t expected_response = new;
    automatic bit got_it;
    forever begin
      apb_master.request_queue.get(expected_request);
      // The cut needs a few cycles to forward the request; wait with a timeout.
      got_it = 1'b0;
      fork
        begin
          apb_slave.request_queue.get(received_request);
          got_it = 1'b1;
        end
        begin
          #((MAX_LATENCY_CYCLES + REQ_MAX_WAIT_CYCLES + 2) * TCLK);
        end
      join_any
      disable fork;
      assert (got_it) else begin
        $error("Request paddr=%h did not reach the slave in time.", expected_request.paddr);
        errors++;
        continue;
      end
      assert (received_request.paddr == expected_request.paddr) else begin
        $error("paddr mismatch: slave saw %h, master sent %h", received_request.paddr, expected_request.paddr);
        errors++;
      end
      assert (received_request.pwrite == expected_request.pwrite) else begin
        $error("pwrite mismatch: slave saw %0b, master sent %0b", received_request.pwrite, expected_request.pwrite);
        errors++;
      end
      if (expected_request.pwrite) begin
        assert (received_request.pwdata == expected_request.pwdata) else begin
          $error("pwdata mismatch: slave saw %h, master sent %h", received_request.pwdata, expected_request.pwdata);
          errors++;
        end
        assert (received_request.pstrb == expected_request.pstrb) else begin
          $error("pstrb mismatch: slave saw %h, master sent %h", received_request.pstrb, expected_request.pstrb);
          errors++;
        end
      end else begin
        // The master pushes its response after the read completes; the slave
        // pushed the expected one when it accepted the request.
        apb_master.response_queue.get(received_response);
        got_it = apb_slave.response_queue.try_get(expected_response);
        assert (got_it) else begin
          $error("Slave has no response queued for the read the master just completed.");
          errors++;
          continue;
        end
        assert (received_response.prdata == expected_response.prdata) else begin
          $error("prdata mismatch: master got %h, slave sent %h", received_response.prdata, expected_response.prdata);
          errors++;
        end
        assert (received_response.pslverr == expected_response.pslverr) else begin
          $error("pslverr mismatch: master got %0b, slave sent %0b", received_response.pslverr, expected_response.pslverr);
          errors++;
        end
      end
    end
  end

  // Termination ------------------------------------------------------------------
  initial begin
    wait(mst_done);
    // Let the last transfer drain through the cut and the slave wait states.
    #((MAX_LATENCY_CYCLES + 2) * TCLK);

    assert (apb_master.request_queue.num() == 0) else begin
      $error("Lost %0d requests (never forwarded to the slave).", apb_master.request_queue.num());
      errors += apb_master.request_queue.num();
    end
    assert (apb_slave.request_queue.num() == 0) else begin
      $error("Slave received %0d requests the master never issued (spurious transfers).",
             apb_slave.request_queue.num());
      errors += apb_slave.request_queue.num();
    end
    assert (mst_xfers == N_TXNS) else begin
      $error("Master side completed %0d transfers, expected %0d.", mst_xfers, N_TXNS);
      errors++;
    end
    assert (slv_xfers == N_TXNS) else begin
      $error("Slave side completed %0d transfers, expected %0d.", slv_xfers, N_TXNS);
      errors++;
    end

    $info("tb_apb_cut (Bypass=%0d): %0d transfers, total number of errors: %0d", Bypass, N_TXNS, errors);
    $stop();
  end

endmodule
