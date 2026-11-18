// Author: Federica Sarnataro
// Description: UC4 - Illegal command.
//              Example of the requirements: RUN in DONE -> ERROR.
//              All the state x command combinations are in tb_csr_fsm.
`timescale 1ns/1ps

module tb_csr_uc4;
    `include "tb_csr_common.svh"

    initial begin
        tb_start();

        // Precondition: Simply-V in DONE
        rt(DONE);
        check_status("UC4 precondition", DONE);

        // Illegal command
        cmd(RUN);
        check_status("UC4 RUN in DONE", ERROR);
        check_outputs(ERROR, "UC4");

        tb_finish("UC4");
    end
endmodule
