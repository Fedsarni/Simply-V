// Author: Federica Sarnataro
// Description: UC2 - New input data, same program.
`timescale 1ns/1ps

module tb_csr_uc2;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();

        // Precondition: program loaded and run once, Simply-V in DONE
        cmd(RESET_CPU);
        cmd(LOAD_PROGRAM);
        wr(A_BOOT, 'h2000);
        cmd(LOAD_INPUT_DATA);
        cmd(RUN);
        rt(DONE);

        // New input data only
        cmd(RESET_CPU);
        cmd(LOAD_INPUT_DATA);
        wr(A_PIN, 'h1000_0100);
        cmd(RUN);
        rd(A_STATUS, v_data);
        assert (v_data == BUSY) else $error("[TB] RUN: STATUS %0d, expected BUSY", v_data);
        assert (boot_addr == 'h2000) else $error("[TB] same program: boot address %0h", boot_addr);
        rd(A_PIN, v_data);
        assert (v_data == 'h1000_0100) else $error("[TB] new PTR_IN %0h", v_data);
        rt(DONE);
        rd(A_STATUS, v_data);
        assert (v_data == DONE) else $error("[TB] runtime DONE: STATUS %0d, expected DONE", v_data);

        $finish;
    end : stim_proc
endmodule
