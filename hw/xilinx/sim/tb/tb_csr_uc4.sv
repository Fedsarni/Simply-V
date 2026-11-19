// Author: Federica Sarnataro
// Description: UC4 - Illegal command (RUN in DONE). All the combinations are in tb_csr_fsm.
`timescale 1ns/1ps

module tb_csr_uc4;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        rt(DONE);
        check_status("precondition: DONE", DONE);

        cmd(RUN);
        check_status("RUN in DONE -> ERROR", ERROR);

        tb_finish("UC4");
    end : stim_proc
endmodule
