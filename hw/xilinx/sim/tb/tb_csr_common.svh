// Author: Federica Sarnataro
// Description: Common part of the simplyv_csr testbenches, included inside each tb_csr_* module:
//              AXI VIP (AXI4-Lite master) -> simplyv_csr, clock, reset and the tasks used by the tests.

import axi_vip_pkg::*;
import axi_vip_mst_pkg::*;

// Register offsets
localparam logic [31:0] A_CMD    = 'h00;
localparam logic [31:0] A_STATUS = 'h04;
localparam logic [31:0] A_BOOT   = 'h08;
localparam logic [31:0] A_PIN    = 'h0C;
localparam logic [31:0] A_POUT   = 'h10;
localparam logic [31:0] A_RT     = 'h14;

// Commands
localparam int RESET_CPU       = 1;
localparam int LOAD_PROGRAM    = 2;
localparam int LOAD_INPUT_DATA = 3;
localparam int RUN             = 4;
localparam int RESET_ALL       = 5;
localparam int HALT            = 6;

// States
localparam int IDLE   = 0;
localparam int BUSY   = 1;
localparam int DONE   = 2;
localparam int ERROR  = 3;
localparam int HALTED = 4;

// AXI responses
localparam logic [1:0] OKAY   = 2'b00;
localparam logic [1:0] SLVERR = 2'b10;

// Test parameters
localparam logic [31:0] BOOT_RST        = 'h1000;  // BOOT_ADDR after reset
localparam int          CLK_HALF_PERIOD = 5;       // ns, 100 MHz clock
localparam int          RST_CYCLES      = 20;      // reset length, the VIP asks at least 16
localparam int          SYS_RST_CYCLES  = 16;      // expected RESET ALL pulse length

// Clock and reset
logic clk   = 1'b0;
logic rst_n = 1'b0;

// Clock assignment
always #(CLK_HALF_PERIOD) clk = ~clk;

// AXI4-Lite bus and CSR outputs
logic [31:0] awaddr;
logic [2:0]  awprot;
logic        awvalid;
logic        awready;
logic [31:0] wdata;
logic [3:0]  wstrb;
logic        wvalid;
logic        wready;
logic [1:0]  bresp;
logic        bvalid;
logic        bready;
logic [31:0] araddr;
logic [2:0]  arprot;
logic        arvalid;
logic        arready;
logic [31:0] rdata;
logic [1:0]  rresp;
logic        rvalid;
logic        rready;
logic        core_rstn;
logic        core_clk_en;
logic        sys_rst;
logic [31:0] boot_addr;

// AXI VIP, AXI4-Lite master
axi_vip_mst vip_u (
    .aclk          ( clk     ),
    .aresetn       ( rst_n   ),
    .m_axi_awaddr  ( awaddr  ),
    .m_axi_awprot  ( awprot  ),
    .m_axi_awvalid ( awvalid ),
    .m_axi_awready ( awready ),
    .m_axi_wdata   ( wdata   ),
    .m_axi_wstrb   ( wstrb   ),
    .m_axi_wvalid  ( wvalid  ),
    .m_axi_wready  ( wready  ),
    .m_axi_bresp   ( bresp   ),
    .m_axi_bvalid  ( bvalid  ),
    .m_axi_bready  ( bready  ),
    .m_axi_araddr  ( araddr  ),
    .m_axi_arprot  ( arprot  ),
    .m_axi_arvalid ( arvalid ),
    .m_axi_arready ( arready ),
    .m_axi_rdata   ( rdata   ),
    .m_axi_rresp   ( rresp   ),
    .m_axi_rvalid  ( rvalid  ),
    .m_axi_rready  ( rready  )
);

// DUT
simplyv_csr #(
    .BOOT_ADDR_RESET ( BOOT_RST ),
    .HALT_EN         ( 1'b1     )
) dut (
    .clk_i             ( clk         ),
    .rst_ni            ( rst_n       ),
    .core_rstn_o       ( core_rstn   ),
    .core_clk_en_o     ( core_clk_en ),
    .sys_rst_o         ( sys_rst     ),
    .boot_addr_o       ( boot_addr   ),
    .s_axilite_awaddr  ( awaddr      ),
    .s_axilite_awprot  ( awprot      ),
    .s_axilite_awvalid ( awvalid     ),
    .s_axilite_awready ( awready     ),
    .s_axilite_wdata   ( wdata       ),
    .s_axilite_wstrb   ( wstrb       ),
    .s_axilite_wvalid  ( wvalid      ),
    .s_axilite_wready  ( wready      ),
    .s_axilite_bresp   ( bresp       ),
    .s_axilite_bvalid  ( bvalid      ),
    .s_axilite_bready  ( bready      ),
    .s_axilite_araddr  ( araddr      ),
    .s_axilite_arprot  ( arprot      ),
    .s_axilite_arvalid ( arvalid     ),
    .s_axilite_arready ( arready     ),
    .s_axilite_rdata   ( rdata       ),
    .s_axilite_rresp   ( rresp       ),
    .s_axilite_rvalid  ( rvalid      ),
    .s_axilite_rready  ( rready      )
);

// Check: count the checks, assert on every value
int v_checks = 0;
int v_errors = 0;

task automatic check(string what, longint got, longint exp);
    v_checks = v_checks + 1;
    assert (got === exp)
    else begin
        v_errors = v_errors + 1;
        $error("[TB] FAIL %s: got %0h, expected %0h", what, got, exp);
    end
endtask

// AXI accesses through the VIP
axi_vip_mst_mst_t mst;

task automatic axi_wr(logic [31:0] addr, logic [31:0] data, output logic [1:0] resp);
    xil_axi_resp_t v_resp;
    mst.AXI4LITE_WRITE_BURST(addr, xil_axi_prot_t'(0), data, v_resp);
    resp = v_resp;
endtask

task automatic axi_rd(logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
    xil_axi_resp_t v_resp;
    bit [31:0]     v_data;
    mst.AXI4LITE_READ_BURST(addr, xil_axi_prot_t'(0), v_data, v_resp);
    data = v_data;
    resp = v_resp;
endtask

// Write a register (expected answer OKAY)
task automatic wr(logic [31:0] addr, logic [31:0] data);
    logic [1:0] v_resp;
    axi_wr(addr, data, v_resp);
    check($sformatf("write %0h response", addr), v_resp, OKAY);
endtask

// Read a register and compare it with the expected value
task automatic check_reg(string what, logic [31:0] addr, logic [31:0] exp);
    logic [31:0] v_data;
    logic [1:0]  v_resp;
    axi_rd(addr, v_data, v_resp);
    check(what, v_data, exp);
endtask

// Master command
task automatic cmd(int c);
    wr(A_CMD, c);
endtask

// Runtime event
task automatic rt(int s);
    wr(A_RT, s);
endtask

// STATUS check
task automatic check_status(string what, int s);
    check_reg(what, A_STATUS, s);
endtask

// RESET ALL pulse: measured at every rising edge, the CPU must stay in reset during it
int v_cnt       = 0;
int v_pulse_len = 0;

always @(posedge clk) begin : pulse_proc
    if (sys_rst) begin
        v_cnt <= v_cnt + 1;
        if (core_rstn !== 1'b0) begin
            check("CPU in reset during RESET ALL", core_rstn, 0);
        end
    end else if (v_cnt != 0) begin
        v_pulse_len <= v_cnt;
        v_cnt       <= 0;
    end
end : pulse_proc

// Wait for the end of the RESET ALL pulse and check its length
task automatic wait_pulse();
    wait (sys_rst == 1'b0);
    repeat (2) @(posedge clk);
    check("RESET ALL pulse length", v_pulse_len, SYS_RST_CYCLES);
endtask

// Expected next state after a command (table 6.1)
function automatic int expected(int st, int c);
    if (c == RESET_ALL) begin
        return BUSY;
    end
    case (st)
        IDLE:    return (c == LOAD_PROGRAM || c == LOAD_INPUT_DATA) ? IDLE : (c == RUN) ? BUSY : ERROR;
        BUSY:    return (c == RESET_CPU) ? IDLE : (c == HALT) ? HALTED : ERROR;
        DONE:    return (c == RESET_CPU) ? IDLE : ERROR;
        HALTED:  return (c == RESET_CPU) ? IDLE : (c == RUN) ? BUSY : ERROR;
        default: return ERROR;   // ERROR: only RESET ALL leaves it
    endcase
endfunction

// Bring the CSR to a state, starting from RESET ALL
task automatic go_to(int st);
    cmd(RESET_ALL);
    wait_pulse();
    case (st)
        IDLE:   cmd(RESET_CPU);
        DONE:   rt(DONE);
        ERROR:  rt(ERROR);
        HALTED: cmd(HALT);
        default: ;               // BUSY: already there after RESET ALL
    endcase
endtask

// Start of the test: VIP, then reset released after a rising edge
task automatic tb_start();
    mst = new("mst", vip_u.inst.IF);
    mst.start_master();
    repeat (RST_CYCLES) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
endtask

// End of the test
task automatic tb_finish(string name);
    $display("RESULT %s: %0d checks, %0d errors -> %s", name, v_checks, v_errors, (v_errors == 0) ? "PASS" : "FAIL");
    $finish;
endtask
