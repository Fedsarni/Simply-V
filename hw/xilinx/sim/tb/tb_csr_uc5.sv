// Author: Federica Sarnataro
// Description: UC5 - Recovery from ERROR: only RESET ALL leaves ERROR.
`timescale 1ns/1ps

module tb_csr_uc5;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();

        // Precondition: registers written, then an illegal command
        cmd(RESET_CPU);
        cmd(LOAD_PROGRAM);
        wr(A_BOOT, 'h2000);
        cmd(HALT);
        check_status("precondition: ERROR", ERROR);

        // Other commands and the runtime do not leave ERROR
        cmd(RESET_CPU);
        check_status("RESET CPU ignored", ERROR);
        cmd(RUN);
        check_status("RUN ignored", ERROR);
        rt(DONE);
        check_status("runtime DONE ignored", ERROR);

        // RESET ALL: back to the power-on state
        cmd(RESET_ALL);
        wait_pulse();
        check_status("RESET ALL -> BUSY", BUSY);
        check_reg("BOOT_ADDR back to default", A_BOOT, BOOT_RST);

        tb_finish("UC5");
    end : stim_proc
endmodule
