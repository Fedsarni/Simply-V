// Author: Federica Sarnataro
// Description: UC4 - Illegal command (RUN in DONE). All the combinations are in tb_csr_fsm.
`timescale 1ns/1ps

module tb_csr_uc4;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        rt(DONE);
        cmd(RUN);
        rd(A_STATUS, v_data);
        assert (v_data == ERROR) else $error("[TB] RUN in DONE: STATUS %0d, expected ERROR", v_data);

        $finish;
    end : stim_proc
endmodule
