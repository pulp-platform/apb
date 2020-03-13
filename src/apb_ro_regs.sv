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

// APB Read-Only Registers
// This module exposes a number of registers (provided on the `reg_i` input) read-only on an
// APB interface.  It responds to reads that are out of range and writes with a slave error.
// The registers are byte addressed and aligned to 4 byte (32bit)! If `reg_data_t` width is less
// than the data width of the APB4 port, the register read response gets extended with `'0`.
module apb_ro_regs #(
  parameter int unsigned NoApbRegs    = 32'd0, // number of read only registers
  parameter int unsigned ApbAddrWidth = 32'd0, // address width of `req_i.paddr`
  parameter int unsigned RegDataWidth = 32'd0, // data width of the registers
  parameter type         req_t        = logic, // APB4 request type
  parameter type         resp_t       = logic, // APB4 response type
  // DEPENDENT PARAMETERS DO NOT OVERWRITE!
  parameter type apb_addr_t = logic[ApbAddrWidth-1:0],
  parameter type reg_data_t = logic[RegDataWidth-1:0]
) (
  // APB Interface
  input  logic                      pclk_i,
  input  logic                      preset_ni,
  input  req_t                      req_i,
  output resp_t                     resp_o,
  // Register Interface
  input  apb_addr_t                 base_addr_i, // base address of the read only registers
  input  reg_data_t [NoApbRegs-1:0] reg_i
);
  localparam int unsigned IdxWidth  = (NoApbRegs > 32'd1) ? $clog2(NoApbRegs) : 32'd1;
  typedef logic [IdxWidth-1:0] idx_t;
  typedef struct packed {
    int unsigned idx;
    apb_addr_t   start_addr;
    apb_addr_t   end_addr;
  } rule_t;

  // signal declarations
  rule_t [NoApbRegs-1:0] addr_map;
  idx_t                  reg_idx;
  logic                  decode_valid;

  // generate address map for the registers
  for (genvar i = 0; i < NoApbRegs; i++) begin: gen_reg_addr_map
    assign addr_map[i] = '{
      idx:        unsigned'(i),
      start_addr: base_addr_i + apb_addr_t'( i        * 32'd4),
      end_addr:   base_addr_i + apb_addr_t'((i+32'd1) * 32'd4)
    };
  end
  // read control
  always_comb begin
    resp_o = '{
      pready:  req_i.psel & req_i.penable,
      prdata:  '0,
      pslverr: apb_pkg::RESP_OKAY
    };
    if (req_i.psel) begin
      if (req_i.pwrite || !decode_valid) begin
        // Error response on writes and decode errors
        resp_o.pslverr = apb_pkg::RESP_SLVERR;
        resp_o.prdata  = reg_data_t'(32'h0BAD_B10C);
      end else begin
        resp_o.prdata = reg_i[reg_idx];
      end
    end
  end

  addr_decode #(
    .NoIndices ( NoApbRegs  ),
    .NoRules   ( NoApbRegs  ),
    .addr_t    ( apb_addr_t ),
    .rule_t    ( rule_t     )
  ) i_addr_decode (
    .addr_i      ( req_i.paddr  ),
    .addr_map_i  ( addr_map     ),
    .idx_o       ( reg_idx      ),
    .dec_valid_o ( decode_valid ),
    .dec_error_o ( /*not used*/ ),
    .en_default_idx_i ( '0      ),
    .default_idx_i    ( '0      )
  );

  // Validate parameters.
  // pragma translate_off
  `ifndef VERILATOR
    initial begin: p_assertions
      assert (NoApbRegs > 32'd0)
          else $fatal(1, "The number of registers must be at least 1!");
      assert (ApbAddrWidth > 32'd2)
          else $fatal(1, "ApbAddrWidth is not wide enough, has to be at least 3 bit wide!");
      assert (RegDataWidth > 32'd0 && RegDataWidth <= 32'd32)
          else $fatal(1, "RegDataWidth has to be: 32'd32 >= RegDataWidth > 0!");
      assert (RegDataWidth <= $bits(resp_o.prdata))
          else $fatal(1, "RegDataWidth has to be: RegDataWidth <= $bits(req_i.prdata)!");
      assert ($bits(resp_o.prdata) == $bits(req_i.pwdata))
          else $fatal(1, "req_i.pwdata has to match resp_o.prdata in width!");
      assert ($bits(req_i.paddr) == ApbAddrWidth)
          else $fatal(1, "AddrWidth does not match req_i.paddr!");
    end
  `endif
  // pragma translate_on
endmodule

`include "apb/assign.svh"
`include "apb/typedef.svh"

module apb_ro_regs_intf #(
  parameter int unsigned NO_APB_REGS    = 32'd0, // number of read only registers
  parameter int unsigned APB_ADDR_WIDTH = 32'd0, // address width of `paddr`
  parameter int unsigned APB_DATA_WIDTH = 32'd0, // data width of the registers
  parameter int unsigned REG_DATA_WIDTH = 32'd0,
  // DEPENDENT PARAMETERS DO NOT OVERWRITE!
  parameter type apb_addr_t = logic[APB_ADDR_WIDTH-1:0],
  parameter type reg_data_t = logic[REG_DATA_WIDTH-1:0]
) (
  // APB Interface
  input  logic  pclk_i,
  input  logic  preset_ni,
  APB.Slave     slv,
  // Register Interface
  input  apb_addr_t                   base_addr_i, // base address of the read only registers
  input  reg_data_t [NO_APB_REGS-1:0] reg_i
);
  localparam int unsigned APB_STRB_WIDTH = cf_math_pkg::ceil_div(APB_DATA_WIDTH, 8);
  typedef logic [APB_DATA_WIDTH-1:0] apb_data_t;
  typedef logic [APB_STRB_WIDTH-1:0] apb_strb_t;

  `APB_TYPEDEF_REQ_T  ( apb_req_t,  apb_addr_t, apb_data_t, apb_strb_t )
  `APB_TYPEDEF_RESP_T ( apb_resp_t, apb_data_t                         )

  apb_req_t  apb_req;
  apb_resp_t apb_resp;

  `APB_ASSIGN_TO_REQ    ( apb_req, slv      )
  `APB_ASSIGN_FROM_RESP ( slv,     apb_resp )

  apb_ro_regs #(
    .NoApbRegs    ( NO_APB_REGS    ),
    .ApbAddrWidth ( APB_ADDR_WIDTH ),
    .RegDataWidth ( REG_DATA_WIDTH ),
    .req_t        ( apb_req_t      ),
    .resp_t       ( apb_resp_t     )
  ) i_apb_ro_regs (
    .pclk_i,
    .preset_ni,
    .req_i       ( apb_req  ),
    .resp_o      ( apb_resp ),
    .base_addr_i,
    .reg_i
  );

  // Validate parameters.
  // pragma translate_off
  `ifndef VERILATOR
    initial begin: p_assertions
      assert (APB_ADDR_WIDTH == $bits(slv.paddr))
          else $fatal(1, "APB_ADDR_WIDTH does not match slv interface!");
      assert (APB_DATA_WIDTH == $bits(slv.pwdata))
          else $fatal(1, "APB_DATA_WIDTH does not match slv interface!");
    end
  `endif
  // pragma translate_on
endmodule
