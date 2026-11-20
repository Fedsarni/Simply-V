// Author: Federica Sarnataro
// Description: UC5 - Recovery from ERROR: only RESET ALL leaves ERROR.
`timescale 1ns/1ps

module tb_csr_uc5;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();

        // Precondition: registers written, then an illegal command (HALT in IDLE)
        cmd(RESET_CPU);
        cmd(LOAD_PROGRAM);
        wr(A_BOOT, 'h2000);
        cmd(HALT);

        // Other commands and the runtime do not leave ERROR
        cmd(RESET_CPU);
        cmd(RUN);
        rt(DONE);
        rd(A_STATUS, v_data);
        assert (v_data == ERROR) else $error("[TB] in ERROR: STATUS %0d, expected ERROR", v_data);

        // RESET ALL: back to the power-on state
        cmd(RESET_ALL);
        wait_pulse();
        rd(A_STATUS, v_data);
        assert (v_data == BUSY) else $error("[TB] RESET ALL: STATUS %0d, expected BUSY", v_data);
        rd(A_BOOT, v_data);
        assert (v_data == BOOT_RST) else $error("[TB] RESET ALL: BOOT_ADDR %0h, expected %0h", v_data, BOOT_RST);

        $finish;
    end : stim_proc
endmodule
