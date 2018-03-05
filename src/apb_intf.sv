// Copyright (c) 2014-2018 ETH Zurich, University of Bologna
// All rights reserved.
//
// This code is under development and not yet released to the public.
// Until it is released, the code is under the copyright of ETH Zurich and
// the University of Bologna, and may contain confidential and/or unpublished
// work. Any reuse/redistribution is strictly forbidden without written
// permission from ETH Zurich.
//
// Bug fixes and contributions will eventually be released under the
// SolderPad open hardware license in the context of the PULP platform
// (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
// University of Bologna.
//
// Fabian Schuiki <zarubaf@iis.ee.ethz.ch>
//
// This file defines the interfaces we support.

interface APB_BUS #(
    parameter int unsigned APB_ADDR_WIDTH = 32,
    parameter int unsigned APB_DATA_WIDTH = 32
);

    logic [APB_ADDR_WIDTH-1:0] paddr;
    logic [APB_DATA_WIDTH-1:0] pwdata;
    logic                      pwrite;
    logic                      psel;
    logic                      penable;
    logic [APB_DATA_WIDTH-1:0] prdata;
    logic                      pready;
    logic                      pslverr;


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
