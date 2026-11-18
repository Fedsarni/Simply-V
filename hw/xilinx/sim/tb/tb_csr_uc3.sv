// Author: Federica Sarnataro
// Description: UC3 - Stuck program.
//              Simply-V stays BUSY until the master timeout, then RESET CPU -> IDLE (CPU in reset).
`timescale 1ns/1ps

module tb_csr_uc3;
    `include "tb_csr_common.svh"

    task automatic stuck(string ctx);
        // Master polling: the runtime never writes DONE
        for (int n = 0; n < 20; n++) check_status({ctx, " polling"}, BUSY);
        // Timeout of the master
        cmd(RESET_CPU);
        check_status({ctx, " RESET CPU"}, IDLE);
        check_outputs(IDLE, ctx);
    endtask

    initial begin
        tb_start();

        // After the PoR (CPU running from the default boot address)
        stuck("UC3 after PoR");

        // After a RUN
        cmd(LOAD_PROGRAM); cmd(LOAD_INPUT_DATA); cmd(RUN);
        check_status("UC3 RUN", BUSY);
        stuck("UC3 after RUN");

        tb_finish("UC3");
    end
endmodule
