// Author: Federica Sarnataro
// Description: Simply-V control and status registers (CSR).
//              Register file and state machine of the Simply-V programming model,
//              with an AXI4-Lite slave interface (32-bit registers, byte offsets).
//
// Register map:
//   0x00 COMMAND    W   master   command to execute (reads as 0)
//   0x04 STATUS     R            state of Simply-V (a write answers SLVERR and is ignored)
//   0x08 BOOT_ADDR  RW  master   boot address of the CPU
//   0x0C PTR_IN     RW  master   pointer to the input data
//   0x10 PTR_OUT    RW  master   pointer to the output data
//   0x14 RT_STATUS  W   runtime  new state written by the runtime (reads as 0):
//                                DONE or ERROR, accepted only in BUSY, any other value is ignored
// Offsets are decoded on addr[7:0]: other offsets answer SLVERR. Write strobes are not used.

// Import headers
`include "simplyv_axi.svh"

module simplyv_csr #(
    parameter int unsigned                LOCAL_DATA_WIDTH = 32,
    parameter int unsigned                LOCAL_ADDR_WIDTH = 32,
    parameter logic [LOCAL_DATA_WIDTH-1:0] BOOT_ADDR_RESET = '0,
    parameter bit                         HALT_EN          = 1'b0, // HALT is optional
    parameter int unsigned                SYS_RST_CYCLES   = 16    // length of the RESET ALL pulse
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,

    // To Simply-V
    output logic                        core_rstn_o,   // reset of the CPU only (active low)
    output logic                        core_clk_en_o, // clock enable of the CPU (HALT)
    output logic                        sys_rst_o,     // reset of the whole Simply-V (pulse, active high)
    output logic [LOCAL_DATA_WIDTH-1:0] boot_addr_o,

    // AXILITE Slave interface
    `DEFINE_AXILITE_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH)
);

    ////////////////
    // Encodings  //
    ////////////////

    // Register offsets
    localparam logic [7:0] OFF_COMMAND   = 8'h00;
    localparam logic [7:0] OFF_STATUS    = 8'h04;
    localparam logic [7:0] OFF_BOOT_ADDR = 8'h08;
    localparam logic [7:0] OFF_PTR_IN    = 8'h0C;
    localparam logic [7:0] OFF_PTR_OUT   = 8'h10;
    localparam logic [7:0] OFF_RT_STATUS = 8'h14;

    // AXI responses
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Commands (written by the master in COMMAND)
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_RESET_CPU       = 1;
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_LOAD_PROGRAM    = 2;
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_LOAD_INPUT_DATA = 3;
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_RUN             = 4;
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_RESET_ALL       = 5;
    localparam logic [LOCAL_DATA_WIDTH-1:0] CMD_HALT            = 6;

    // States (read in STATUS)
    typedef enum logic [2:0] {
        ST_IDLE  = 3'd0,
        ST_BUSY  = 3'd1,
        ST_DONE  = 3'd2,
        ST_ERROR = 3'd3,
        ST_HALT  = 3'd4
    } state_e;

    ///////////////
    // Registers //
    ///////////////

    state_e                                state_q, state_d;
    logic [LOCAL_DATA_WIDTH-1:0]           boot_addr_q, ptr_in_q, ptr_out_q;
    logic [$clog2(SYS_RST_CYCLES+1)-1:0]   sys_rst_cnt_q, sys_rst_cnt_d;

    ///////////////////////
    // AXI4-Lite slave   //
    ///////////////////////
    // A write is accepted when AW and W are both valid and the previous B has been taken.
    // A read is accepted when the previous R has been taken.

    logic                        wr, rd;
    logic [7:0]                  woffset, roffset;
    logic                        waddr_ok, raddr_ok;
    logic [LOCAL_DATA_WIDTH-1:0] wdata;

    assign wr       = s_axilite_awvalid & s_axilite_wvalid & ~s_axilite_bvalid;
    assign rd       = s_axilite_arvalid & ~s_axilite_rvalid;

    assign s_axilite_awready = wr;
    assign s_axilite_wready  = wr;
    assign s_axilite_arready = rd;

    assign woffset  = s_axilite_awaddr[7:0];
    assign roffset  = s_axilite_araddr[7:0];
    assign wdata    = s_axilite_wdata;
    // STATUS is read-only: a write to it answers SLVERR
    assign waddr_ok = (woffset inside {OFF_COMMAND, OFF_BOOT_ADDR, OFF_PTR_IN, OFF_PTR_OUT, OFF_RT_STATUS});
    assign raddr_ok = (roffset inside {OFF_COMMAND, OFF_STATUS, OFF_BOOT_ADDR, OFF_PTR_IN, OFF_PTR_OUT, OFF_RT_STATUS});

    logic cmd_valid;    // master wrote COMMAND
    logic status_wr;    // runtime wrote RT_STATUS
    logic reset_all;    // RESET ALL in this cycle

    assign cmd_valid = wr & (woffset == OFF_COMMAND);
    assign status_wr = wr & (woffset == OFF_RT_STATUS);
    assign reset_all = cmd_valid & (wdata == CMD_RESET_ALL);

    ////////////////////
    // State machine  //
    ////////////////////
    // Table 6.1 of the programming model: a command that is not legal
    // in the current state moves Simply-V to ERROR.

    always_comb begin : fsm_next_state
        state_d = state_q;

        if (cmd_valid) begin
            if (wdata == CMD_RESET_ALL) begin
                // Legal from every state: same as the power-on reset
                state_d = ST_BUSY;
            end else begin
                case (state_q)
                    ST_BUSY: begin
                        if      (wdata == CMD_RESET_CPU)                    state_d = ST_IDLE;
                        else if (wdata == CMD_HALT && HALT_EN)              state_d = ST_HALT;
                        else                                                state_d = ST_ERROR;
                    end
                    ST_DONE: begin
                        if      (wdata == CMD_RESET_CPU)                    state_d = ST_IDLE;
                        else                                                state_d = ST_ERROR;
                    end
                    ST_IDLE: begin
                        if      (wdata == CMD_LOAD_PROGRAM ||
                                 wdata == CMD_LOAD_INPUT_DATA)              state_d = ST_IDLE;
                        else if (wdata == CMD_RUN)                          state_d = ST_BUSY;
                        else                                                state_d = ST_ERROR;
                    end
                    ST_HALT: begin
                        if      (wdata == CMD_RESET_CPU)                    state_d = ST_IDLE;
                        else if (wdata == CMD_RUN)                          state_d = ST_BUSY;
                        else                                                state_d = ST_ERROR;
                    end
                    // ERROR: every command but RESET ALL is ignored
                    default:                                                state_d = state_q;
                endcase
            end
        end else if (status_wr && state_q == ST_BUSY) begin
            // Runtime events: end of job or error
            if      (wdata == LOCAL_DATA_WIDTH'(ST_DONE))  state_d = ST_DONE;
            else if (wdata == LOCAL_DATA_WIDTH'(ST_ERROR)) state_d = ST_ERROR;
        end
    end

    // RESET ALL pulse counter
    always_comb begin : sys_rst_counter
        sys_rst_cnt_d = sys_rst_cnt_q;
        if (reset_all)                sys_rst_cnt_d = SYS_RST_CYCLES[$bits(sys_rst_cnt_q)-1:0];
        else if (sys_rst_cnt_q != '0) sys_rst_cnt_d = sys_rst_cnt_q - 1'b1;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin : registers
        if (!rst_ni) begin
            // After the power-on reset Simply-V is in BUSY
            state_q       <= ST_BUSY;
            boot_addr_q   <= BOOT_ADDR_RESET;
            ptr_in_q      <= '0;
            ptr_out_q     <= '0;
            sys_rst_cnt_q <= '0;
        end else begin
            state_q       <= state_d;
            sys_rst_cnt_q <= sys_rst_cnt_d;
            if (reset_all) begin
                // RESET ALL: registers back to their default
                boot_addr_q <= BOOT_ADDR_RESET;
                ptr_in_q    <= '0;
                ptr_out_q   <= '0;
            end else if (wr) begin
                if (woffset == OFF_BOOT_ADDR) boot_addr_q <= wdata;
                if (woffset == OFF_PTR_IN)    ptr_in_q    <= wdata;
                if (woffset == OFF_PTR_OUT)   ptr_out_q   <= wdata;
            end
        end
    end

    ///////////////////
    // Bus response  //
    ///////////////////

    always_ff @(posedge clk_i or negedge rst_ni) begin : axilite_response
        if (!rst_ni) begin
            s_axilite_bvalid <= 1'b0;
            s_axilite_bresp  <= RESP_OKAY;
            s_axilite_rvalid <= 1'b0;
            s_axilite_rresp  <= RESP_OKAY;
            s_axilite_rdata  <= '0;
        end else begin
            // B channel
            if (wr) begin
                s_axilite_bvalid <= 1'b1;
                s_axilite_bresp  <= waddr_ok ? RESP_OKAY : RESP_SLVERR;
            end else if (s_axilite_bready) begin
                s_axilite_bvalid <= 1'b0;
            end
            // R channel
            if (rd) begin
                s_axilite_rvalid <= 1'b1;
                s_axilite_rresp  <= raddr_ok ? RESP_OKAY : RESP_SLVERR;
                case (roffset)
                    OFF_STATUS:    s_axilite_rdata <= LOCAL_DATA_WIDTH'(state_q);
                    OFF_BOOT_ADDR: s_axilite_rdata <= boot_addr_q;
                    OFF_PTR_IN:    s_axilite_rdata <= ptr_in_q;
                    OFF_PTR_OUT:   s_axilite_rdata <= ptr_out_q;
                    default:       s_axilite_rdata <= '0; // COMMAND and RT_STATUS read as 0
                endcase
            end else if (s_axilite_rready) begin
                s_axilite_rvalid <= 1'b0;
            end
        end
    end

    /////////////
    // Outputs //
    /////////////

    // CPU held in reset while IDLE and during the RESET ALL pulse
    assign core_rstn_o   = (state_q != ST_IDLE) & (sys_rst_cnt_q == '0);
    assign core_clk_en_o = (state_q != ST_HALT);
    assign sys_rst_o     = (sys_rst_cnt_q != '0);
    assign boot_addr_o   = boot_addr_q;

endmodule : simplyv_csr
