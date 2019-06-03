// Copyright (c) 2014 ETH Zurich, University of Bologna
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// An APB2 interface
interface APB;

  localparam ADDR_WIDTH = 32;
  localparam DATA_WIDTH = 32;
  localparam STRB_WIDTH = DATA_WIDTH / 8;

  typedef logic [ADDR_WIDTH-1:0]  addr_t;
  typedef logic [DATA_WIDTH-1:0]  data_t;
  typedef logic            [2:0]  prot_t;
  typedef logic [STRB_WIDTH-1:0]  strb_t;

  addr_t  paddr;
  prot_t  pprot;
  logic   psel;
  logic   penable;
  logic   pwrite;
  data_t  pwdata;
  strb_t  pstrb;
  logic   pready;
  data_t  prdata;
  logic   pslverr;


    // Master Side
    modport Master (
        output paddr,  pwdata,  pwrite, psel,  penable,
        input  prdata,          pready,        pslverr
    );

    // Slave Side
    modport Slave (
        input   paddr,  pwdata,  pwrite, psel,  penable,
        output  prdata,          pready,        pslverr
    );

    /// The interface as an output (issuing requests, initiator, master).
    modport out (
        output paddr,  pwdata,  pwrite, psel,  penable,
        input  prdata,          pready,        pslverr
    );

    /// The interface as an input (accepting requests, target, slave)
    modport in (
        input   paddr,  pwdata,  pwrite, psel,  penable,
        output  prdata,          pready,        pslverr
    );


endinterface
