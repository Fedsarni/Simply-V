// Author: Federica Sarnataro
// Description: UC1 - Load and run program.
`timescale 1ns/1ps

module tb_csr_uc1;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        check_status("precondition: BUSY after power-on", BUSY);

        cmd(RESET_CPU);
        check_status("RESET CPU -> IDLE", IDLE);
        check("CPU in reset", core_rstn, 0);

        cmd(LOAD_PROGRAM);
        wr(A_BOOT, 'h2000);
        check("boot address to the CPU", boot_addr, 'h2000);

        cmd(LOAD_INPUT_DATA);
        wr(A_PIN, 'h1000_0000);
        wr(A_POUT, 'h1000_1000);
        check_status("after the LOAD commands: IDLE", IDLE);

        cmd(RUN);
        check_status("RUN -> BUSY", BUSY);
        check("CPU running", core_rstn, 1);

        // Runtime: reads the pointers, then signals the end of the job
        check_reg("PTR_IN", A_PIN, 'h1000_0000);
        check_reg("PTR_OUT", A_POUT, 'h1000_1000);
        rt(DONE);
        check_status("runtime DONE -> DONE", DONE);

        tb_finish("UC1");
    end : stim_proc
endmodule
