// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// APB Cut Description:
// This module cuts paths on the APB interface.

module apb_cut #(
  parameter bit  Bypass = 1'b0, // Bypass the cut or not
  parameter type apb_req_t  = logic, // APB request strcut
  parameter type apb_resp_t = logic  // APB response struct
)(
  input  logic clk_i,
  input  logic rst_ni,

  // APB target interface
  input  apb_req_t  apb_req_i,
  output apb_resp_t apb_rsp_o,

  // APB initiator interface
  output apb_req_t  apb_req_o,
  input  apb_resp_t apb_rsp_i
);

  if (Bypass) begin: gen_bypass
    assign apb_req_o = apb_req_i;
    assign apb_rsp_o = apb_rsp_i;
  end else begin: gen_cut

    logic psel, penable, pready;

    apb_req_t apb_req_q;
    apb_resp_t apb_rsp_q;

    typedef enum logic [1:0] {
      Idle,
      Setup,
      Access,
      Response
    } state_t;

    state_t state_d, state_q;

    always_comb begin
      state_d = state_q;
      psel = 1'b0;
      penable = 1'b0;
      pready = 1'b0;
      case (state_q)
        Idle: begin
          if (apb_req_i.psel && !apb_req_i.penable)
            state_d = Setup;
        end
        Setup: begin
          state_d = Access;
          psel = 1'b1;
        end
        Access: begin
          psel = 1'b1;
          penable = 1'b1;
          if (apb_rsp_i.pready) state_d = Response;
         end
        Response: begin
          pready = 1'b1;
          state_d = Idle;
        end
      endcase
    end

    assign apb_req_o.psel = psel;
    assign apb_req_o.penable = penable;
    assign apb_req_o.paddr = apb_req_q.paddr;
    assign apb_req_o.pprot = apb_req_q.pprot;
    assign apb_req_o.pwrite = apb_req_q.pwrite;
    assign apb_req_o.pwdata = apb_req_q.pwdata;
    assign apb_req_o.pstrb = apb_req_q.pstrb;
    assign apb_rsp_o.pready = pready;
    assign apb_rsp_o.prdata = apb_rsp_q.prdata;
    assign apb_rsp_o.pslverr = apb_rsp_q.pslverr;

    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni) begin
        state_q <= Idle;
        apb_req_q <= '0;
        apb_rsp_q <= '0;
      end else begin
        state_q <= state_d;
        apb_req_q <= apb_req_i;
        apb_rsp_q <= apb_rsp_i;
      end
    end
  end

endmodule // apb_cut

`include "apb/typedef.svh"
`include "apb/assign.svh"

module apb_cut_intf #(
  parameter bit          BYPASS = 1'b0,
  parameter int unsigned APB_ADDR_WIDTH = 0,
  parameter int unsigned APB_DATA_WIDTH = 0
)(
  input logic clk_i,
  input logic rst_ni,
  APB.Slave   target,
  APB.Master  initiator
);

  typedef logic [APB_ADDR_WIDTH-1:0] addr_t;
  typedef logic [APB_DATA_WIDTH-1:0] data_t;
  typedef logic [APB_DATA_WIDTH/8-1:0] strb_t;

  `APB_TYPEDEF_REQ_T(apb_req_t, addr_t, data_t, strb_t)
  `APB_TYPEDEF_RESP_T(apb_resp_t, data_t)

  apb_req_t target_req, initiator_req;
  apb_resp_t target_resp, initiator_resp;

  `APB_ASSIGN_FROM_REQ(initiator, initiator_req)
  `APB_ASSIGN_TO_RESP(initiator_resp, initiator)

  `APB_ASSIGN_TO_REQ(target_req, target)
  `APB_ASSIGN_FROM_RESP(target, target_resp)

  apb_cut #(
    .Bypass (BYPASS), // Bypass the cut or not
    .apb_req_t (apb_req_t), // APB request strcut
    .apb_resp_t (apb_resp_t) // APB response struct
  ) i_apb_cut (
    .clk_i,
    .rst_ni,

    // APB target interface
    .apb_req_i (target_req),
    .apb_rsp_o (target_resp),

    // APB initiator interface
    .apb_req_o (initiator_req),
    .apb_rsp_i (initiator_resp)
  );

endmodule // apb_cut_intf
