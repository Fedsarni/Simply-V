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
    int v_exp;

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
                rd(A_STATUS, v_data);
                assert (v_data == v_exp) else $error("[TB] state %0d, command %0d: STATUS %0d, expected %0d", v_states[s], v_commands[c], v_data, v_exp);
            end : cmd_loop
        end : state_cmd_loop

        // 2. Runtime: DONE and ERROR change the state only in BUSY, other values are ignored
        foreach (v_states[s]) begin : state_event_loop
            foreach (v_events[e]) begin : event_loop
                go_to(v_states[s]);
                rt(v_events[e]);
                v_exp = (v_states[s] == BUSY && v_events[e] != 7) ? v_events[e] : v_states[s];
                rd(A_STATUS, v_data);
                assert (v_data == v_exp) else $error("[TB] state %0d, RT_STATUS %0d: STATUS %0d, expected %0d", v_states[s], v_events[e], v_data, v_exp);
            end : event_loop
        end : state_event_loop

        // 3. Outputs: CPU in reset only in IDLE, clock stopped only in HALT
        go_to(IDLE);
        assert (core_rstn == 1'b0) else $error("[TB] IDLE: CPU not in reset");
        go_to(HALTED);
        assert (core_clk_en == 1'b0) else $error("[TB] HALT: CPU clock not stopped");

        // 4. Registers
        wr(A_BOOT, 'hDEAD_BEE0);
        rd(A_BOOT, v_data);
        assert (v_data == 'hDEAD_BEE0) else $error("[TB] BOOT_ADDR read back %0h", v_data);
        assert (boot_addr == 'hDEAD_BEE0) else $error("[TB] boot address to the CPU %0h", boot_addr);
        rd(A_CMD, v_data);
        assert (v_data == 0) else $error("[TB] COMMAND reads %0h, expected 0", v_data);
        rd(A_RT, v_data);
        assert (v_data == 0) else $error("[TB] RT_STATUS reads %0h, expected 0", v_data);

        // 5. SLVERR: write to STATUS (read-only) and offsets that do not exist
        go_to(BUSY);
        axi_wr(A_STATUS, DONE, v_resp);
        assert (v_resp == SLVERR) else $error("[TB] write to STATUS: response %0b, expected SLVERR", v_resp);
        rd(A_STATUS, v_data);
        assert (v_data == BUSY) else $error("[TB] write to STATUS not ignored: STATUS %0d", v_data);
        axi_rd('h18, v_data, v_resp);
        assert (v_resp == SLVERR) else $error("[TB] read 0x18: response %0b, expected SLVERR", v_resp);

        // 6. Full command word: 0x104 is not RUN
        go_to(IDLE);
        cmd('h104);
        rd(A_STATUS, v_data);
        assert (v_data == ERROR) else $error("[TB] command 0x104: STATUS %0d, expected ERROR", v_data);

        $finish;
    end : stim_proc
endmodule
