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
        check_status("precondition: DONE", DONE);

        // New input data only
        cmd(RESET_CPU);
        cmd(LOAD_INPUT_DATA);
        wr(A_PIN, 'h1000_0100);
        cmd(RUN);
        check_status("RUN -> BUSY", BUSY);
        check("same program: boot address unchanged", boot_addr, 'h2000);
        check_reg("new PTR_IN", A_PIN, 'h1000_0100);
        rt(DONE);
        check_status("runtime DONE -> DONE", DONE);

        tb_finish("UC2");
    end : stim_proc
endmodule
