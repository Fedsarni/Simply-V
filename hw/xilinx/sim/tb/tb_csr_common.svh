// Author: Federica Sarnataro
// Description: Common part of the simplyv_csr testbenches, included inside each tb_csr_* module.
//              AXI VIP master (AXI4-Lite) -> simplyv_csr, clock and reset, access tasks and checks.
//              The expected behaviour is table 6.1 and the Use Cases of the CSR requirements.

import axi_vip_pkg::*;
import axi_vip_mst_pkg::*;

localparam bit          HALT_EN        = 1'b1;
localparam int unsigned SYS_RST_CYCLES = 16;
localparam logic [31:0] BOOT_RST       = 32'h0000_1000;

// Programming model
localparam int RESET_CPU = 1, LOAD_PROGRAM = 2, LOAD_INPUT_DATA = 3, RUN = 4, RESET_ALL = 5, HALT = 6;
localparam int IDLE = 0, BUSY = 1, DONE = 2, ERROR = 3, HALTED = 4;
localparam logic [31:0] A_CMD = 32'h00, A_STATUS = 32'h04, A_BOOT = 32'h08, A_PIN = 32'h0C, A_POUT = 32'h10;
localparam logic [1:0]  OKAY = 2'b00, SLVERR = 2'b10;

/////////////////////
// Clock and reset //
/////////////////////

logic clk = 1'b0, rst_n = 1'b0;
always #5 clk = ~clk;

/////////////////
// AXI4-Lite   //
/////////////////

logic [31:0] awaddr, wdata, araddr, rdata;
logic [2:0]  awprot, arprot;
logic [3:0]  wstrb;
logic [1:0]  bresp, rresp;
logic        awvalid, awready, wvalid, wready, bvalid, bready;
logic        arvalid, arready, rvalid, rready;

logic        core_rstn, core_clk_en, sys_rst;
logic [31:0] boot_addr;

axi_vip_mst vip_u (
    .aclk           ( clk     ),
    .aresetn        ( rst_n   ),
    .m_axi_awaddr   ( awaddr  ), .m_axi_awprot  ( awprot  ), .m_axi_awvalid ( awvalid ), .m_axi_awready ( awready ),
    .m_axi_wdata    ( wdata   ), .m_axi_wstrb   ( wstrb   ), .m_axi_wvalid  ( wvalid  ), .m_axi_wready  ( wready  ),
    .m_axi_bresp    ( bresp   ), .m_axi_bvalid  ( bvalid  ), .m_axi_bready  ( bready  ),
    .m_axi_araddr   ( araddr  ), .m_axi_arprot  ( arprot  ), .m_axi_arvalid ( arvalid ), .m_axi_arready ( arready ),
    .m_axi_rdata    ( rdata   ), .m_axi_rresp   ( rresp   ), .m_axi_rvalid  ( rvalid  ), .m_axi_rready  ( rready  )
);

simplyv_csr #(
    .BOOT_ADDR_RESET ( BOOT_RST       ),
    .HALT_EN         ( HALT_EN        ),
    .SYS_RST_CYCLES  ( SYS_RST_CYCLES )
) dut (
    .clk_i              ( clk         ),
    .rst_ni             ( rst_n       ),
    .core_rstn_o        ( core_rstn   ),
    .core_clk_en_o      ( core_clk_en ),
    .sys_rst_o          ( sys_rst     ),
    .boot_addr_o        ( boot_addr   ),
    .s_axilite_awaddr   ( awaddr  ), .s_axilite_awprot  ( awprot  ), .s_axilite_awvalid ( awvalid ), .s_axilite_awready ( awready ),
    .s_axilite_wdata    ( wdata   ), .s_axilite_wstrb   ( wstrb   ), .s_axilite_wvalid  ( wvalid  ), .s_axilite_wready  ( wready  ),
    .s_axilite_bresp    ( bresp   ), .s_axilite_bvalid  ( bvalid  ), .s_axilite_bready  ( bready  ),
    .s_axilite_araddr   ( araddr  ), .s_axilite_arprot  ( arprot  ), .s_axilite_arvalid ( arvalid ), .s_axilite_arready ( arready ),
    .s_axilite_rdata    ( rdata   ), .s_axilite_rresp   ( rresp   ), .s_axilite_rvalid  ( rvalid  ), .s_axilite_rready  ( rready  )
);

////////////
// Checks //
////////////

int errors = 0, checks = 0;

task automatic check(string what, longint got, longint exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[%0t] FAIL %s: got %0h expected %0h", $time, what, got, exp);
    end
endtask

// RESET ALL pulse: length and CPU held in reset during the pulse
int pulse_len = 0, pulses = 0;
always @(posedge clk) begin
    if (sys_rst) begin
        pulse_len++;
        if (core_rstn !== 1'b0) begin errors++; $display("[%0t] FAIL core_rstn high during RESET ALL", $time); end
    end else if (pulse_len != 0) begin
        check("RESET ALL pulse length", pulse_len, SYS_RST_CYCLES);
        pulse_len = 0;
        pulses++;
    end
end

// Outputs to Simply-V in a given state (outside the RESET ALL pulse)
task automatic check_outputs(int st, string ctx);
    check({ctx, " core_rstn"},   core_rstn,   (st != IDLE));
    check({ctx, " core_clk_en"}, core_clk_en, (st != HALTED));
    check({ctx, " sys_rst"},     sys_rst,     0);
endtask

//////////////////////
// AXI VIP access   //
//////////////////////

axi_vip_mst_mst_t mst;

task automatic axi_init();
    mst = new("mst", vip_u.inst.IF);
    mst.start_master();
endtask

task automatic axi_wr(input logic [31:0] addr, input logic [31:0] data, output logic [1:0] resp);
    xil_axi_resp_t r;
    mst.AXI4LITE_WRITE_BURST(addr, xil_axi_prot_t'(0), data, r);
    resp = r;
endtask

task automatic axi_rd(input logic [31:0] addr, output logic [31:0] data, output logic [1:0] resp);
    xil_axi_resp_t r;
    bit [31:0]     d;
    mst.AXI4LITE_READ_BURST(addr, xil_axi_prot_t'(0), d, r);
    data = d;
    resp = r;
endtask

//////////////////////
// End AXI VIP      //
//////////////////////

// Master: command
task automatic cmd(int c);
    logic [1:0] r;
    axi_wr(A_CMD, c, r);
    check($sformatf("cmd %0d BRESP", c), r, OKAY);
endtask

// Runtime: write STATUS (DONE or ERROR)
task automatic rt(int v);
    logic [1:0] r;
    axi_wr(A_STATUS, v, r);
    check($sformatf("STATUS <= %0d BRESP", v), r, OKAY);
endtask

task automatic status(output int s);
    logic [31:0] d;
    logic [1:0]  r;
    axi_rd(A_STATUS, d, r);
    s = int'(d);
endtask

task automatic check_status(string ctx, int exp);
    int s;
    status(s);
    check({ctx, " STATUS"}, s, exp);
endtask

task automatic wr_reg(logic [31:0] addr, logic [31:0] data);
    logic [1:0] r;
    axi_wr(addr, data, r);
    check($sformatf("write %0h BRESP", addr), r, OKAY);
endtask

task automatic check_reg(string ctx, logic [31:0] addr, logic [31:0] exp);
    logic [31:0] d;
    logic [1:0]  r;
    axi_rd(addr, d, r);
    check({ctx, $sformatf(" read %0h", addr)}, d, exp);
endtask

task automatic wait_pulse();
    repeat (2) @(posedge clk);
    wait (sys_rst == 1'b0);
    @(posedge clk);
endtask

// Expected next state (table 6.1)
function automatic int expected(int st, int c);
    if (c == RESET_ALL) return BUSY;
    case (st)
        BUSY:    return (c == RESET_CPU) ? IDLE : (c == HALT && HALT_EN) ? HALTED : ERROR;
        DONE:    return (c == RESET_CPU) ? IDLE : ERROR;
        IDLE:    return (c == LOAD_PROGRAM || c == LOAD_INPUT_DATA) ? IDLE : (c == RUN) ? BUSY : ERROR;
        HALTED:  return (c == RESET_CPU) ? IDLE : (c == RUN) ? BUSY : ERROR;
        ERROR:   return ERROR;
        default: return -1;
    endcase
endfunction

// Bring Simply-V into a given state, starting from RESET ALL
task automatic goto(int st);
    cmd(RESET_ALL); wait_pulse();
    case (st)
        IDLE:    cmd(RESET_CPU);
        DONE:    rt(DONE);
        ERROR:   rt(ERROR);
        HALTED:  cmd(HALT);
        default: ;
    endcase
    check_status($sformatf("goto %0d", st), st);
endtask

// Start: VIP, reset (ARESETN low for at least 16 cycles, as the VIP asks)
task automatic tb_start();
    axi_init();
    repeat (20) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);
endtask

task automatic tb_finish(string name);
    $display("RESULT %s: %0d checks, %0d errors -> %s", name, checks, errors, (errors == 0) ? "PASS" : "FAIL");
    $finish;
endtask

// Watchdog
initial begin
    #10ms;
    $display("RESULT timeout -> FAIL");
    $finish;
end
