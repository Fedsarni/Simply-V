// Author: Federica Sarnataro
// Description:
//   Guard between one MEM port of a core and its MEM-to-AXI bridge (axi_from_mem), for the
//   core-only reset (RESET CPU of the CSR). The core is reset alone, while the bridge keeps
//   running: without this guard, a reset in the middle of a transaction leaves the bridge
//   and the AXI bus in a wrong state (request dropped before the grant, response delivered
//   to the restarted core).
//   While the core is in reset, the guard:
//   - keeps a request that was not granted yet until the bridge grants it;
//   - drops the responses of the requests issued before the reset;
//   - releases the core reset only when no request is pending and no response is expected.
//   One guard for each port: the core reset is the AND of core_rstn_o of all the guards,
//   and it goes back to all the guards on core_active_i.

module mem_reset_guard #(
    parameter int unsigned DATA_WIDTH      = 32,
    parameter int unsigned ADDR_WIDTH      = 32,
    parameter int unsigned MAX_OUTSTANDING = 1   // as MaxRequests of axi_from_mem
) (
    input  logic                      clk_i,
    input  logic                      rst_ni,          // system reset

    // Core reset
    input  logic                      core_rstn_i,     // requested core reset (active low)
    output logic                      core_rstn_o,     // core reset released by this guard
    input  logic                      core_active_i,   // AND of core_rstn_o of all the guards

    // MEM slave port, from the core
    input  logic                      s_mem_req_i,
    input  logic [ADDR_WIDTH-1 : 0]   s_mem_addr_i,
    input  logic                      s_mem_we_i,
    input  logic [DATA_WIDTH-1 : 0]   s_mem_wdata_i,
    input  logic [DATA_WIDTH/8-1 : 0] s_mem_be_i,
    output logic                      s_mem_gnt_o,
    output logic                      s_mem_valid_o,
    output logic [DATA_WIDTH-1 : 0]   s_mem_rdata_o,
    output logic                      s_mem_error_o,

    // MEM master port, to the bridge
    output logic                      m_mem_req_o,
    output logic [ADDR_WIDTH-1 : 0]   m_mem_addr_o,
    output logic                      m_mem_we_o,
    output logic [DATA_WIDTH-1 : 0]   m_mem_wdata_o,
    output logic [DATA_WIDTH/8-1 : 0] m_mem_be_o,
    input  logic                      m_mem_gnt_i,
    input  logic                      m_mem_valid_i,
    input  logic [DATA_WIDTH-1 : 0]   m_mem_rdata_i,
    input  logic                      m_mem_error_i
);

    localparam int unsigned CNT_WIDTH = $clog2(MAX_OUTSTANDING + 1);

    // Request not granted at the last clock edge, kept while the core is in reset
    logic                      hold_req_q;
    logic [ADDR_WIDTH-1 : 0]   hold_addr_q;
    logic                      hold_we_q;
    logic [DATA_WIDTH-1 : 0]   hold_wdata_q;
    logic [DATA_WIDTH/8-1 : 0] hold_be_q;

    // Granted requests still waiting for the response
    logic [CNT_WIDTH-1 : 0]    outstanding_q;
    logic [CNT_WIDTH-1 : 0]    outstanding_d;

    // Core reset released by this guard
    logic                      release_q;
    logic                      idle;

    ////////////////////////
    // Request to bridge  //
    ////////////////////////

    // Core running: requests go through. Core in reset: only the kept request
    assign m_mem_req_o   = core_active_i ? s_mem_req_i   : hold_req_q;
    assign m_mem_addr_o  = core_active_i ? s_mem_addr_i  : hold_addr_q;
    assign m_mem_we_o    = core_active_i ? s_mem_we_i    : hold_we_q;
    assign m_mem_wdata_o = core_active_i ? s_mem_wdata_i : hold_wdata_q;
    assign m_mem_be_o    = core_active_i ? s_mem_be_i    : hold_be_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin : hold_request
        if (!rst_ni) begin
            hold_req_q   <= 1'b0;
            hold_addr_q  <= '0;
            hold_we_q    <= 1'b0;
            hold_wdata_q <= '0;
            hold_be_q    <= '0;
        end else if (core_active_i) begin
            // Remember the request in case the core is reset before the grant
            hold_req_q   <= s_mem_req_i & ~m_mem_gnt_i;
            hold_addr_q  <= s_mem_addr_i;
            hold_we_q    <= s_mem_we_i;
            hold_wdata_q <= s_mem_wdata_i;
            hold_be_q    <= s_mem_be_i;
        end else if (m_mem_gnt_i) begin
            // The kept request is granted
            hold_req_q   <= 1'b0;
        end
    end

    /////////////////////////
    // Response to core    //
    /////////////////////////

    // No grant and no response to a core in reset
    assign s_mem_gnt_o   = core_active_i & m_mem_gnt_i;
    assign s_mem_valid_o = core_active_i & m_mem_valid_i;
    assign s_mem_rdata_o = m_mem_rdata_i;
    assign s_mem_error_o = m_mem_error_i;

    always_comb begin : count_outstanding
        outstanding_d = outstanding_q;
        if (m_mem_req_o && m_mem_gnt_i) begin
            outstanding_d = outstanding_d + 1'b1;
        end
        if (m_mem_valid_i) begin
            outstanding_d = outstanding_d - 1'b1;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : outstanding_counter
        if (!rst_ni) begin
            outstanding_q <= '0;
        end else begin
            outstanding_q <= outstanding_d;
        end
    end

    /////////////////////////
    // Core reset release  //
    /////////////////////////

    assign idle = ~hold_req_q & (outstanding_q == '0);

    always_ff @(posedge clk_i or negedge rst_ni) begin : release_core
        if (!rst_ni) begin
            release_q <= 1'b0;
        end else if (!core_rstn_i) begin
            release_q <= 1'b0;
        end else if (idle) begin
            release_q <= 1'b1;
        end
    end

    // The reset reaches the core at once, the release waits for the bridge
    assign core_rstn_o = core_rstn_i & release_q;

endmodule : mem_reset_guard
