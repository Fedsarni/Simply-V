// Author: Federica Sarnataro
// Description: UC3 - Stuck program: the master times out and stops the CPU.
`timescale 1ns/1ps

module tb_csr_uc3;
    `include "tb_csr_common.svh"

    initial begin : stim_proc
        tb_start();
        cmd(RESET_CPU);
        cmd(LOAD_PROGRAM);
        cmd(LOAD_INPUT_DATA);
        cmd(RUN);

        // Polling: the runtime never writes DONE
        repeat (5) begin
            check_status("polling: still BUSY", BUSY);
        end

        // Timeout of the master
        cmd(RESET_CPU);
        check_status("RESET CPU -> IDLE", IDLE);
        check("CPU in reset", core_rstn, 0);

        tb_finish("UC3");
    end : stim_proc
endmodule
