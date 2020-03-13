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

  localparam int unsigned NoApbRegs = 32'd10;

  localparam int unsigned ApbAddrWidth = 32'd32;
  localparam int unsigned ApbDataWidth = 32'd27;
  localparam int unsigned RegDataWidth = 32'd16;

  localparam time CyclTime = 10ns;
  localparam time ApplTime = 2ns;
  localparam time TestTime = 8ns;

  typedef logic [ApbAddrWidth-1:0] apb_addr_t;
  typedef logic [ApbDataWidth-1:0] apb_data_t;
  typedef logic [RegDataWidth-1:0] reg_data_t;



  logic                      clk;
  logic                      rst_n;
  logic                      done;
  apb_addr_t                 base_addr;
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


    for (int unsigned i = 32'h0002_FF00; i < 32'h0004_0000; i++) begin
      addr = apb_addr_t'(i);
      apb_master.read(addr, data, resp);
      $display("Read from addr: %0h", addr);
      $display("Read data: %0h", data);
      $display("Read resp: %0h", resp);
      repeat (3) @(posedge clk);
    end


    done <= 1'b1;

  end

  initial begin : proc_end_sim
    @(posedge done);
    $stop();
  end

  initial begin : proc_set_const
    base_addr <= apb_addr_t'(32'h0003_0000);
    for (int unsigned i = 0; i < NoApbRegs; i++) begin
      reg_data[i] = reg_data_t'(i);
    end
  end

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
    .base_addr_i ( base_addr ),
    .reg_i       ( reg_data  )
  );

endmodule
