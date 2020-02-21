// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Wolfgang Roenninger <wreonnin@ethz.ch>

// Description: Testbench for `apb_ro_regs`.

`include "apb/assign.svh"

module tb_apb_ro_regs;

  localparam int unsigned NoApbRegs = 32'd342;

  localparam int unsigned ApbAddrWidth = 32'd32;
  localparam int unsigned ApbDataWidth = 32'd27;
  localparam int unsigned ApbStrbWidth = cf_math_pkg::ceil_div(ApbDataWidth, 8);
  localparam int unsigned RegDataWidth = 32'd16;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  typedef logic [ApbAddrWidth-1:0] apb_addr_t;
  typedef logic [ApbDataWidth-1:0] apb_data_t;
  typedef logic [ApbStrbWidth-1:0] apb_strb_t;
  typedef logic [RegDataWidth-1:0] reg_data_t;

  localparam apb_addr_t BaseAddr      = 32'h0003_0000;
  localparam apb_addr_t TestStartAddr = 32'h0002_FF00;
  localparam apb_addr_t TestEndAddr   = 32'h0003_0F00;

  logic                      clk;
  logic                      rst_n;
  logic                      done;
  reg_data_t [NoApbRegs-1:0] reg_data;


  APB_DV #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) apb_slave_dv(clk);
  APB #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth )
  ) apb_slave();
  `APB_ASSIGN ( apb_slave, apb_slave_dv )

  //-----------------------------------
  // Clock generator
  //-----------------------------------
  clk_rst_gen #(
    .CLK_PERIOD    ( CyclTime ),
    .RST_CLK_CYCLES( 5        )
  ) i_clk_gen (
    .clk_o (clk),
    .rst_no(rst_n)
  );

  apb_test::apb_driver #(
    .ADDR_WIDTH ( ApbAddrWidth ),
    .DATA_WIDTH ( ApbDataWidth ),
    .TA         ( ApplTime     ),
    .TT         ( TestTime     )
  ) apb_master = new(apb_slave_dv);

  initial begin : proc_apb_master
    automatic apb_addr_t addr;
    automatic apb_data_t data;
    automatic logic      resp;

    done <= 1'b0;
    @(posedge rst_n);
    apb_master.reset_master();
    repeat (10) @(posedge clk);
    apb_master.write( BaseAddr, apb_data_t'(32'd0000_0000), apb_strb_t'(4'hF), resp);
    $display("Write addr: %0h", addr);
    $display("Write data: %0h", data);
    $display("Write resp: %0h", resp);
    assert(resp == apb_pkg::RESP_SLVERR);

    for (int unsigned i = TestStartAddr; i < TestEndAddr; i++) begin
      addr = apb_addr_t'(i);
      apb_master.read(addr, data, resp);
      $display("Read from addr: %0h", addr);
      $display("Read data: %0h", data);
      $display("Read resp: %0h", resp);
      repeat ($urandom_range(0,5)) @(posedge clk);
    end
    done <= 1'b1;
  end

  initial begin : proc_end_sim
    @(posedge done);
    repeat(10) @(posedge clk);
    $stop();
  end

  initial begin : proc_set_reg_data
    for (int unsigned i = 0; i < NoApbRegs; i++) begin
      reg_data[i] = reg_data_t'($urandom());
    end
  end

  // pragma translate_off
  `ifndef VERILATOR
  // Assertions to determine correct APB protocol sequencing
  default disable iff (!rst_n);
  // when psel is not asserted, the bus is in the idle state
  sequence APB_IDLE;
    !apb_slave.psel;
  endsequence

  // when psel is set and penable is not, it is the setup state
  sequence APB_SETUP;
    apb_slave.psel && !apb_slave.penable;
  endsequence

  // when psel and penable are set it is the access state
  sequence APB_ACCESS;
    apb_slave.psel && apb_slave.penable;
  endsequence

  sequence APB_RESP_OKAY;
    apb_slave.pready && (apb_slave.pslverr == apb_pkg::RESP_OKAY);
  endsequence

  sequence APB_RESP_SLVERR;
    apb_slave.pready && (apb_slave.pslverr == apb_pkg::RESP_SLVERR);
  endsequence

  // APB Transfer is APB state going from setup to access
  sequence APB_TRANSFER;
    APB_SETUP ##1 APB_ACCESS;
  endsequence

  apb_complete:   assert property ( @(posedge clk)
      (APB_SETUP |-> APB_TRANSFER));

  apb_penable:    assert property ( @(posedge clk)
      (apb_slave.penable && apb_slave.psel && apb_slave.pready |=> (!apb_slave.penable)));

  control_stable: assert property ( @(posedge clk)
      (APB_TRANSFER |-> $stable({apb_slave.pwrite, apb_slave.paddr})));

  apb_valid:      assert property ( @(posedge clk)
      (APB_TRANSFER |-> ((!{apb_slave.pwrite, apb_slave.pstrb, apb_slave.paddr}) !== 1'bx)));

  write_stable:   assert property ( @(posedge clk)
      ((apb_slave.penable && apb_slave.pwrite) |-> $stable(apb_slave.pwdata)));

  strb_stable:    assert property ( @(posedge clk)
      ((apb_slave.penable && apb_slave.pwrite) |-> $stable(apb_slave.pstrb)));

  correct_data:   assert property ( @(posedge clk)
      (APB_TRANSFER and APB_RESP_OKAY and !apb_slave.pwrite)
      |-> (apb_slave.prdata == reg_data[apb_slave.paddr>>2])) else
      $fatal(1, "Unexpected read response!");
  `endif
  // pragma translate_on


  // Dut
  apb_ro_regs_intf #(
    .NO_APB_REGS    ( NoApbRegs    ),
    .APB_ADDR_WIDTH ( ApbAddrWidth ),
    .APB_DATA_WIDTH ( ApbDataWidth ),
    .REG_DATA_WIDTH ( RegDataWidth )
  ) i_apb_ro_regs_dut (
    .pclk_i      ( clk       ),
    .preset_ni   ( rst_n     ),
    .slv         ( apb_slave ),
    .base_addr_i ( BaseAddr  ),
    .reg_i       ( reg_data  )
  );

endmodule
