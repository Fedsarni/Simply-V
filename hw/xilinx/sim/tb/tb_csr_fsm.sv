// Author: Federica Sarnataro
// Description: Complete test of simplyv_csr: every state x every command (table 6.1),
//              runtime events, outputs, registers and SLVERR answers.
`timescale 1ns/1ps

module tb_csr_fsm;
    `include "tb_csr_common.svh"

    // What is tested: 0 and 7 are unknown commands, 7 is not a valid runtime event
    int v_states[5]   = '{IDLE, BUSY, DONE, ERROR, HALTED};
    int v_commands[8] = '{0, RESET_CPU, LOAD_PROGRAM, LOAD_INPUT_DATA, RUN, RESET_ALL, HALT, 7};
    int v_events[3]   = '{DONE, ERROR, 7};

    logic [31:0] v_data;
    logic [1:0]  v_resp;
    int          v_exp;

    initial begin : stim_proc
        tb_start();

        // 1. Every state x every command
        foreach (v_states[s]) begin : state_cmd_loop
            foreach (v_commands[c]) begin : cmd_loop
                go_to(v_states[s]);
                cmd(v_commands[c]);
                if (v_commands[c] == RESET_ALL) begin
                    wait_pulse();
                end
                v_exp = expected(v_states[s], v_commands[c]);
                check_status($sformatf("state %0d, command %0d", v_states[s], v_commands[c]), v_exp);
            end : cmd_loop
        end : state_cmd_loop

        // 2. Runtime: DONE and ERROR change the state only in BUSY, other values are ignored
        foreach (v_states[s]) begin : state_event_loop
            foreach (v_events[e]) begin : event_loop
                go_to(v_states[s]);
                rt(v_events[e]);
                v_exp = (v_states[s] == BUSY && v_events[e] != 7) ? v_events[e] : v_states[s];
                check_status($sformatf("state %0d, RT_STATUS %0d", v_states[s], v_events[e]), v_exp);
            end : event_loop
        end : state_event_loop

        // 3. Outputs: CPU in reset only in IDLE, clock stopped only in HALT
        go_to(IDLE);
        check("IDLE: CPU in reset", core_rstn, 0);
        go_to(HALTED);
        check("HALT: CPU clock stopped", core_clk_en, 0);

        // 4. Registers
        wr(A_BOOT, 'hDEAD_BEE0);
        check_reg("BOOT_ADDR read back", A_BOOT, 'hDEAD_BEE0);
        check("boot address to the CPU", boot_addr, 'hDEAD_BEE0);
        check_reg("COMMAND reads 0", A_CMD, 0);
        check_reg("RT_STATUS reads 0", A_RT, 0);

        // 5. SLVERR: write to STATUS (read-only) and offsets that do not exist
        go_to(BUSY);
        axi_wr(A_STATUS, DONE, v_resp);
        check("write to STATUS -> SLVERR", v_resp, SLVERR);
        check_status("write to STATUS ignored", BUSY);
        axi_rd('h18, v_data, v_resp);
        check("read 0x18 -> SLVERR", v_resp, SLVERR);

        // 6. Full command word: 0x104 is not RUN
        go_to(IDLE);
        cmd('h104);
        check_status("command 0x104 -> ERROR", ERROR);

        tb_finish("FSM");
    end : stim_proc
endmodule
