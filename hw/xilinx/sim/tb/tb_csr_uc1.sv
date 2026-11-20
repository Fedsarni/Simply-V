// Author: Federica Sarnataro
// Description: UC1 - Load and run program.
`timescale 1ns/1ps

module tb_csr_uc1;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        rd(A_STATUS, v_data);
        assert (v_data == BUSY) else $error("[TB] after power-on: STATUS %0d, expected BUSY", v_data);

        cmd(RESET_CPU);
        rd(A_STATUS, v_data);
        assert (v_data == IDLE) else $error("[TB] RESET CPU: STATUS %0d, expected IDLE", v_data);
        assert (core_rstn == 1'b0) else $error("[TB] RESET CPU: CPU not in reset");

        cmd(LOAD_PROGRAM);
        wr(A_BOOT, 'h2000);
        assert (boot_addr == 'h2000) else $error("[TB] boot address to the CPU: %0h", boot_addr);

        cmd(LOAD_INPUT_DATA);
        wr(A_PIN, 'h1000_0000);
        wr(A_POUT, 'h1000_1000);
        rd(A_STATUS, v_data);
        assert (v_data == IDLE) else $error("[TB] after the LOAD commands: STATUS %0d, expected IDLE", v_data);

        cmd(RUN);
        rd(A_STATUS, v_data);
        assert (v_data == BUSY) else $error("[TB] RUN: STATUS %0d, expected BUSY", v_data);
        assert (core_rstn == 1'b1) else $error("[TB] RUN: CPU still in reset");

        // Runtime: reads the pointers, then signals the end of the job
        rd(A_PIN, v_data);
        assert (v_data == 'h1000_0000) else $error("[TB] PTR_IN %0h", v_data);
        rd(A_POUT, v_data);
        assert (v_data == 'h1000_1000) else $error("[TB] PTR_OUT %0h", v_data);
        rt(DONE);
        rd(A_STATUS, v_data);
        assert (v_data == DONE) else $error("[TB] runtime DONE: STATUS %0d, expected DONE", v_data);

        $finish;
    end : stim_proc
endmodule
