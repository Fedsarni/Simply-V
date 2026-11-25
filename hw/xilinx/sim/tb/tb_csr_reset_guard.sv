// Author: Federica Sarnataro
// Description:
//   Testbench of mem_reset_guard: RESET CPU of the CSR at random times, while the core
//   reads and writes through the MEM-to-AXI bridge.
//   - Core model: random requests, kept until the grant as the MEM protocol requires;
//     the core reset clears it at once, as in the real core (request dropped).
//   - Bridge model: as axi_from_mem with MaxRequests = 1, random grant and response delays.
//   Checks (assert):
//   - bridge side: a request is never dropped or changed before the grant (the same rules
//     as the assertions of axi_lite_from_mem);
//   - core side: no response while the core is in reset, and every response matches the
//     oldest request of the core;
//   - the resets hit both risky cases: a request not granted yet, a response still expected.
//   GUARD = 0 connects the core to the bridge without the guard: the checks must fail.
//   Run with run_csr_tb.tcl: PASS if it reaches $finish and no [TB] error is printed.

`timescale 1ns/1ps

module tb_csr_reset_guard;

    parameter bit          GUARD  = 1'b1;
    localparam int unsigned RESETS = 2000;
    localparam int unsigned DW     = 32;
    localparam int unsigned AW     = 32;

    // Clock and resets
    logic            clk;
    logic            rst_n;
    logic            core_rstn_req;   // from the CSR
    logic            core_rstn;       // to the core

    // Core side
    logic            c_req;
    logic [AW-1:0]   c_addr;
    logic            c_we;
    logic [DW-1:0]   c_wdata;
    logic [DW/8-1:0] c_be;
    logic            c_gnt;
    logic            c_valid;
    logic [DW-1:0]   c_rdata;
    logic            c_error;

    // Bridge side
    logic            b_req;
    logic [AW-1:0]   b_addr;
    logic            b_we;
    logic [DW-1:0]   b_wdata;
    logic [DW/8-1:0] b_be;
    logic            b_gnt;
    logic            b_valid;
    logic [DW-1:0]   b_rdata;
    logic            b_error;

    // Statistics
    int unsigned     responses_checked;
    int unsigned     resets_with_pending;
    int unsigned     resets_with_outstanding;
    int unsigned     errors;

    ///////////
    // Clock //
    ///////////

    initial begin : clock_gen
        clk = 1'b0;
        forever begin
            #5 clk = ~clk;
        end
    end

    /////////
    // DUT //
    /////////

    if (GUARD) begin : gen_guard
        mem_reset_guard #(
            .DATA_WIDTH      ( DW ),
            .ADDR_WIDTH      ( AW ),
            .MAX_OUTSTANDING ( 1  )
        ) dut (
            .clk_i          ( clk           ),
            .rst_ni         ( rst_n         ),
            .core_rstn_i    ( core_rstn_req ),
            .core_rstn_o    ( core_rstn     ),
            .core_active_i  ( core_rstn     ),
            .s_mem_req_i    ( c_req         ),
            .s_mem_addr_i   ( c_addr        ),
            .s_mem_we_i     ( c_we          ),
            .s_mem_wdata_i  ( c_wdata       ),
            .s_mem_be_i     ( c_be          ),
            .s_mem_gnt_o    ( c_gnt         ),
            .s_mem_valid_o  ( c_valid       ),
            .s_mem_rdata_o  ( c_rdata       ),
            .s_mem_error_o  ( c_error       ),
            .m_mem_req_o    ( b_req         ),
            .m_mem_addr_o   ( b_addr        ),
            .m_mem_we_o     ( b_we          ),
            .m_mem_wdata_o  ( b_wdata       ),
            .m_mem_be_o     ( b_be          ),
            .m_mem_gnt_i    ( b_gnt         ),
            .m_mem_valid_i  ( b_valid       ),
            .m_mem_rdata_i  ( b_rdata       ),
            .m_mem_error_i  ( b_error       )
        );
    end else begin : gen_no_guard
        assign core_rstn = core_rstn_req;
        assign b_req     = c_req;
        assign b_addr    = c_addr;
        assign b_we      = c_we;
        assign b_wdata   = c_wdata;
        assign b_be      = c_be;
        assign c_gnt     = b_gnt;
        assign c_valid   = b_valid;
        assign c_rdata   = b_rdata;
        assign c_error   = b_error;
    end

    ////////////////
    // Core model //
    ////////////////

    logic [DW-1:0] expected_q [$];   // expected responses, oldest first

    always @(posedge clk or negedge core_rstn) begin : core_model
        logic [AW-1:0] v_addr;
        if (!core_rstn) begin
            // Reset: the request is dropped at once and the core forgets everything
            c_req   <= 1'b0;
            c_addr  <= '0;
            c_we    <= 1'b0;
            c_wdata <= '0;
            c_be    <= '0;
            expected_q.delete();
        end else begin
            // Response: it must match the oldest request
            if (c_valid) begin
                assert (expected_q.size() > 0) else begin
                    $error("[TB] response to the core with no request");
                    errors++;
                end
                if (expected_q.size() > 0) begin
                    assert (c_rdata == expected_q[0]) else begin
                        $error("[TB] wrong response: 0x%08x instead of 0x%08x", c_rdata, expected_q[0]);
                        errors++;
                    end
                    expected_q.pop_front();
                    responses_checked++;
                end
            end
            // Granted request: wait for its response
            if (c_req && c_gnt) begin
                expected_q.push_back(c_we ? '0 : (c_addr ^ 32'hA5A5_A5A5));
                c_req <= 1'b0;
            end
            // New request, kept until the grant
            if ( (!c_req || c_gnt) && ($urandom_range(0, 1) == 1) ) begin
                v_addr  = $urandom();
                c_req   <= 1'b1;
                c_addr  <= v_addr;
                c_we    <= ($urandom_range(0, 3) == 0);
                c_wdata <= $urandom();
                c_be    <= 4'hF;
            end
        end
    end

    //////////////////
    // Bridge model //
    //////////////////

    logic          busy_q;       // one request in flight, as MaxRequests = 1
    logic          ready_q;      // random delay of the grant
    int unsigned   latency_q;    // cycles to the response
    logic [DW-1:0] rdata_q;

    assign b_gnt   = b_req & ~busy_q & ready_q;
    assign b_valid = busy_q & (latency_q == 0);
    assign b_rdata = rdata_q;
    assign b_error = 1'b0;

    always @(posedge clk or negedge rst_n) begin : bridge_model
        if (!rst_n) begin
            busy_q    <= 1'b0;
            ready_q   <= 1'b0;
            latency_q <= 0;
            rdata_q   <= '0;
        end else begin
            ready_q <= ($urandom_range(0, 2) != 0);
            if (b_valid) begin
                busy_q <= 1'b0;
            end else if (busy_q) begin
                latency_q <= latency_q - 1;
            end
            if (b_req && b_gnt) begin
                busy_q    <= 1'b1;
                latency_q <= $urandom_range(0, 4);
                rdata_q   <= b_we ? '0 : (b_addr ^ 32'hA5A5_A5A5);
            end
        end
    end

    ////////////////////////////////
    // Bridge side protocol rules //
    ////////////////////////////////

    logic          prev_wait_q;  // request not granted at the last clock edge
    logic [AW-1:0] prev_addr_q;
    logic          prev_we_q;
    logic [DW-1:0] prev_wdata_q;

    always @(posedge clk or negedge rst_n) begin : bridge_rules
        if (!rst_n) begin
            prev_wait_q  <= 1'b0;
            prev_addr_q  <= '0;
            prev_we_q    <= 1'b0;
            prev_wdata_q <= '0;
        end else begin
            if (prev_wait_q) begin
                assert (b_req) else begin
                    $error("[TB] request dropped before the grant");
                    errors++;
                end
                assert ( (b_addr == prev_addr_q) && (b_we == prev_we_q) && (b_wdata == prev_wdata_q) ) else begin
                    $error("[TB] request changed before the grant");
                    errors++;
                end
            end
            prev_wait_q  <= b_req & ~b_gnt;
            prev_addr_q  <= b_addr;
            prev_we_q    <= b_we;
            prev_wdata_q <= b_wdata;
        end
    end

    // No response to a core in reset
    always @(posedge clk) begin : core_reset_rules
        if (rst_n && !core_rstn) begin
            assert (!c_valid) else begin
                $error("[TB] response to a core in reset");
                errors++;
            end
        end
    end

    ////////////////////
    // Reset stimulus //
    ////////////////////

    initial begin : reset_stimulus
        responses_checked       = 0;
        resets_with_pending     = 0;
        resets_with_outstanding = 0;
        errors                  = 0;
        rst_n                   = 1'b0;
        core_rstn_req           = 1'b1;
        repeat (5) @(posedge clk);
        rst_n <= 1'b1;
        for (int unsigned v_i = 0; v_i < RESETS; v_i++) begin
            repeat ($urandom_range(1, 20)) @(posedge clk);
            // RESET CPU: count the risky cases it hits
            if (c_req && !c_gnt) begin
                resets_with_pending++;
            end
            if (busy_q) begin
                resets_with_outstanding++;
            end
            core_rstn_req <= 1'b0;
            repeat ($urandom_range(1, 6)) @(posedge clk);
            // RUN
            core_rstn_req <= 1'b1;
        end
        repeat (50) @(posedge clk);

        $display("[INFO] GUARD %0d: %0d RESET CPU, %0d with a request not granted, %0d with a response expected",
                 GUARD, RESETS, resets_with_pending, resets_with_outstanding);
        $display("[INFO] %0d responses checked, %0d errors", responses_checked, errors);
        assert (resets_with_pending > 0) else $error("[TB] no reset with a request not granted");
        assert (resets_with_outstanding > 0) else $error("[TB] no reset with a response expected");
        assert (responses_checked > 1000) else $error("[TB] too few responses checked");
        $finish;
    end

endmodule : tb_csr_reset_guard
